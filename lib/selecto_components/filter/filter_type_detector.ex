defmodule SelectoComponents.Filter.FilterTypeDetector do
  @moduledoc """
  Automatically detects and suggests appropriate filter types based on data characteristics.
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @doc """
  Detect filter type based on field metadata and sample data.
  """
  def detect_filter_type(field, sample_data \\ []) do
    cond do
      # Check field metadata first
      field[:filter_type] -> field.filter_type
      # Check data type
      field[:type] == :boolean -> :boolean
      field[:type] == :date -> :date_range
      field[:type] == :datetime -> :date_range
      field[:type] == :integer -> detect_numeric_filter(field, sample_data)
      field[:type] == :decimal -> detect_numeric_filter(field, sample_data)
      field[:type] == :float -> detect_numeric_filter(field, sample_data)
      field[:type] == :string -> detect_string_filter(field, sample_data)
      # Check field name patterns
      String.ends_with?(field.name, "_at") -> :date_range
      String.ends_with?(field.name, "_date") -> :date_range
      String.ends_with?(field.name, "_id") -> :select
      String.ends_with?(field.name, "_type") -> :multi_select
      String.ends_with?(field.name, "_status") -> :multi_select
      String.contains?(field.name, "price") -> :numeric_range
      String.contains?(field.name, "amount") -> :numeric_range
      String.contains?(field.name, "count") -> :numeric_range
      String.contains?(field.name, "email") -> :text_with_validation
      String.contains?(field.name, "phone") -> :text_with_validation
      String.contains?(field.name, "url") -> :text_with_validation
      # Default
      true -> :text
    end
  end

  @doc """
  Render appropriate filter component based on detected type.
  """
  def auto_filter(assigns) do
    filter_type = detect_filter_type(assigns.field, assigns[:sample_data])
    assigns = assign(assigns, :filter_type, filter_type)

    ~H"""
    <div class="auto-filter">
      <%= case @filter_type do %>
        <% :boolean -> %>
          <.boolean_filter field={@field} value={@value} target={@target} />
        <% :date_range -> %>
          <.text_filter field={@field} value={@value} target={@target} />
        <% :numeric_range -> %>
          <.text_filter field={@field} value={@value} target={@target} />
        <% :select -> %>
          <.select_filter
            field={@field}
            value={@value}
            options={get_unique_values(@sample_data, @field)}
            target={@target}
          />
        <% :multi_select -> %>
          <.select_filter
            field={@field}
            value={@value}
            options={get_unique_values(@sample_data, @field)}
            target={@target}
          />
        <% :text_with_validation -> %>
          <.validated_text_filter
            field={@field}
            value={@value}
            validation={get_validation_pattern(@field)}
            target={@target}
          />
        <% _ -> %>
          <.text_filter field={@field} value={@value} target={@target} />
      <% end %>

      <%!-- Filter type indicator --%>
      <div class="mt-1 text-xs text-gray-500">
        Auto-detected: {humanize_filter_type(@filter_type)}
        <button
          type="button"
          class="ml-2 text-blue-600 hover:text-blue-800"
          phx-click={show_filter_options()}
        >
          Change
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Boolean filter component.
  """
  def boolean_filter(assigns) do
    ~H"""
    <div class="flex space-x-2">
      <button
        type="button"
        class={[
          "px-3 py-1 text-sm rounded",
          @value == true && "bg-green-500 text-white",
          @value != true && "bg-gray-100 text-gray-700 hover:bg-gray-200"
        ]}
        phx-click="set_filter"
        phx-value-field={@field.name}
        phx-value-value="true"
        phx-target={@target}
      >
        Yes
      </button>
      <button
        type="button"
        class={[
          "px-3 py-1 text-sm rounded",
          @value == false && "bg-red-500 text-white",
          @value != false && "bg-gray-100 text-gray-700 hover:bg-gray-200"
        ]}
        phx-click="set_filter"
        phx-value-field={@field.name}
        phx-value-value="false"
        phx-target={@target}
      >
        No
      </button>
      <button
        type="button"
        class={[
          "px-3 py-1 text-sm rounded",
          @value == nil && "bg-blue-500 text-white",
          @value != nil && "bg-gray-100 text-gray-700 hover:bg-gray-200"
        ]}
        phx-click="set_filter"
        phx-value-field={@field.name}
        phx-value-value=""
        phx-target={@target}
      >
        Any
      </button>
    </div>
    """
  end

  @doc """
  Select filter component.
  """
  def select_filter(assigns) do
    ~H"""
    <select
      class="w-full px-3 py-1 text-sm border border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500"
      phx-change="set_filter"
      phx-target={@target}
      name={"filter[#{@field.name}]"}
    >
      <option value="">All {@field.label}</option>
      <%= for option <- @options do %>
        <option value={option} selected={@value == option}>
          {option}
        </option>
      <% end %>
    </select>
    """
  end

  @doc """
  Text filter component.
  """
  def text_filter(assigns) do
    ~H"""
    <div class="flex space-x-2">
      <select
        class="px-2 py-1 text-sm border border-gray-300 rounded"
        phx-change="set_filter_operator"
        phx-target={@target}
        name={"filter_op[#{@field.name}]"}
      >
        <option value="contains">Contains</option>
        <option value="starts_with">Starts with</option>
        <option value="ends_with">Ends with</option>
        <option value="equals">Equals</option>
        <option value="not_equals">Not equals</option>
      </select>
      <input
        type="text"
        class="flex-1 px-3 py-1 text-sm border border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500"
        placeholder={"Filter #{@field.label}..."}
        value={@value}
        phx-blur="set_filter"
        phx-target={@target}
        name={"filter[#{@field.name}]"}
      />
    </div>
    """
  end

  @doc """
  Validated text filter with pattern matching.
  """
  def validated_text_filter(assigns) do
    ~H"""
    <div class="space-y-1">
      <input
        type="text"
        class={[
          "w-full px-3 py-1 text-sm border rounded focus:ring-blue-500",
          validate_input(@value, @validation) && "border-gray-300 focus:border-blue-500",
          !validate_input(@value, @validation) && "border-red-300 focus:border-red-500"
        ]}
        placeholder={get_placeholder(@validation)}
        value={@value}
        phx-blur="set_filter"
        phx-keyup="validate_filter"
        phx-target={@target}
        name={"filter[#{@field.name}]"}
        pattern={@validation.pattern}
      />
      <%= if @value && !validate_input(@value, @validation) do %>
        <p class="text-xs text-red-600">{@validation.message}</p>
      <% end %>
    </div>
    """
  end

  # Private helper functions

  defp detect_numeric_filter(field, sample_data) do
    if Enum.empty?(sample_data) do
      :numeric_range
    else
      values = get_field_values(sample_data, field)
      unique_count = values |> Enum.uniq() |> length()

      cond do
        unique_count <= 10 -> :multi_select
        unique_count <= 50 -> :select
        true -> :numeric_range
      end
    end
  end

  defp detect_string_filter(field, sample_data) do
    if Enum.empty?(sample_data) do
      :text
    else
      values = get_field_values(sample_data, field)
      unique_count = values |> Enum.uniq() |> length()
      avg_length = values |> Enum.map(&String.length/1) |> Enum.sum() |> div(length(values))

      cond do
        unique_count <= 5 -> :multi_select
        unique_count <= 20 -> :select
        avg_length > 100 -> :text_search
        true -> :text
      end
    end
  end

  defp get_field_values(data, field) do
    Enum.map(data, &Map.get(&1, field.name))
    |> Enum.reject(&is_nil/1)
  end

  defp get_unique_values(data, field) do
    get_field_values(data, field)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp get_validation_pattern(field) do
    cond do
      String.contains?(field.name, "email") ->
        %{
          pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
          message: "Please enter a valid email address"
        }

      String.contains?(field.name, "phone") ->
        %{
          pattern: "^[+]?[(]?[0-9]{3}[)]?[-\\s\\.]?[0-9]{3}[-\\s\\.]?[0-9]{4,6}$",
          message: "Please enter a valid phone number"
        }

      String.contains?(field.name, "url") ->
        %{
          pattern: "^https?://[\\w\\-]+(\\.[\\w\\-]+)+[/#?]?.*$",
          message: "Please enter a valid URL"
        }

      true ->
        %{pattern: ".*", message: ""}
    end
  end

  defp validate_input("", _validation), do: true
  defp validate_input(nil, _validation), do: true

  defp validate_input(value, validation) do
    Regex.match?(~r/#{validation.pattern}/, value)
  end

  defp get_placeholder(validation) do
    pattern = validation.pattern

    cond do
      String.contains?(pattern, "email") -> "user@example.com"
      String.contains?(pattern, "phone") -> "+1 (555) 123-4567"
      String.contains?(pattern, "url") -> "https://example.com"
      true -> "Enter value..."
    end
  end

  defp humanize_filter_type(type) do
    type
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp show_filter_options do
    JS.toggle(
      to: "#filter-type-selector",
      in: {"ease-out duration-200", "opacity-0 scale-95", "opacity-100 scale-100"},
      out: {"ease-in duration-150", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
  end
end
