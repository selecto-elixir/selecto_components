defmodule SelectoComponents.Components.FilterForms do
  use Phoenix.LiveComponent
  import SelectoComponents.Components.Common

  def render(assigns) do
    filter_def =
      Map.get(assigns.custom_filters, assigns.filter["filter"]) ||
        Map.get(assigns.columns, assigns.filter["filter"])

    #  Map.get(assigns.filters(filter))

    type = Map.get(filter_def, :filter_type, filter_def.type)
    assigns = assign(assigns, type: type, def: filter_def)

    ~H"""
      <div>
        <input name={"filters[#{@uuid}][filter]"} type="hidden" value={@filter["filter"]}/>
        <input name={"filters[#{@uuid}][section]"} type="hidden" value={@section}/>
        <input name={"filters[#{@uuid}][index]"} type="hidden" value={@index}/>
        <input name={"filters[#{@uuid}][uuid]"} type="hidden" value={@uuid}/>

        <%= render_form(%{type: @type, uuid: @uuid, id: @id, filter: @filter, def: @def} ) %>
        <%!-- TODO: SHOW ERRORS --%>

      </div>
    """
  end

  def render_form(%{type: :tsvector} = assigns) do
    def = assigns.def
    valmap = assigns.filter
    assigns = Map.put(assigns, :valmap, valmap) |> Map.put(:def, def) |> Map.put(:comp, Map.get(valmap, "comp", "="))

    ~H"""
      <div>
        <label class="text-gray-900 dark:text-gray-100">
          <%= @def.name %>
          <.sc_input name={"filters[#{@uuid}][value]"} value={@valmap["value"]}/>
        </label>
      </div>
    """
  end

  def render_form(%{type: :string} = assigns) do
    def = assigns.def
    valmap = assigns.filter
    assigns = Map.put(assigns, :valmap, valmap) |> Map.put(:def, def) |> Map.put(:comp, Map.get(valmap, "comp", "="))

    ~H"""
      <div>
        <label class="text-gray-900 dark:text-gray-100">
          <%= @def.name %>
          <.sc_select_with_slot name={"filters[#{@uuid}][comp]"}>
            <option value="=" selected={@comp == "="}>Equals</option>
            <option value="!=" selected={@comp == "!="}>Not Equals</option>
            <option value="starts" selected={@comp == "starts"}>Starts With</option>
            <option value="ends" selected={@comp == "ends"}>Ends With</option>
            <option value="contains" selected={@comp == "contains"}>Contains</option>
            <option value="null" selected={@comp == "null"}>Null</option>
            <option value="not_null" selected={@comp == "not_null"}>Not Null</option>
          </.sc_select_with_slot>
          <%= if @comp in ~w(= != starts ends contains) do %>
            <.sc_input name={"filters[#{@uuid}][value]"} value={@valmap["value"]}/>
              <label class="text-gray-900 dark:text-gray-100"><input type="checkbox" name={"filters[#{@uuid}][ignore_case]"} checked={Map.get(@valmap, "ignore_case") == "Y"} value="Y" class="mr-1 text-blue-600 dark:text-blue-400 focus:ring-blue-500 dark:focus:ring-blue-400"/>Ignore Case</label>
          <% end %>
        </label>
      </div>
    """
  end

  def render_form(%{type: t} = assigns) when t in [:id, :integer] do
    def = assigns.def
    valmap = assigns.filter
    assigns = Map.put(assigns, :valmap, valmap) |> Map.put(:def, def) |> Map.put(:comp, Map.get(valmap, "comp", "="))
    ~H"""
      <div>
        <label class="text-gray-900 dark:text-gray-100">
          <%= @def.name %>
          <.sc_select_with_slot name={"filters[#{@uuid}][comp]"}>
            <option value="=" selected={@comp == "="}>Equals</option>
            <option value="!=" selected={@comp == "!="}>Not Equals</option>
            <option value="<" selected={@comp == "<"}>Less Than</option>
            <option value=">" selected={@comp == ">"}>Greater Than</option>
            <option value="<=" selected={@comp == "<="}>Less Than/Equal</option>
            <option value=">=" selected={@comp == ">="}>Greater Than/Equal</option>
            <option value="between" selected={@comp == "between"}>Between</option>
            <option value="null" selected={@comp == "null"}>Null</option>
            <option value="not_null" selected={@comp == "not_null"}>Not Null</option>
          </.sc_select_with_slot>
        </label>

        <%= if @comp in ~w(= != < > <= >= between) do %>
          <.sc_input name={"filters[#{@uuid}][value]"} value={@valmap["value"]}/>
          <%= if @comp == "between" do %>
            <span class="text-gray-900 dark:text-gray-100">and</span> <.sc_input name={"filters[#{@uuid}][value2]"} value={@valmap["value2"]}/>
          <% end %>
        <% end %>
      </div>
    """
  end

  def render_form(%{type: t} = assigns) when t in [:decimal, :float] do
    def = assigns.def
    valmap = assigns.filter

    assigns = Map.put(assigns, :valmap, valmap) |> Map.put(:def, def) |> Map.put(:comp, Map.get(valmap, "comp", "="))

    ~H"""
      <div>
        <label class="text-gray-900 dark:text-gray-100">
          <%= @def.name %>
          <.sc_select_with_slot name={"filters[#{@uuid}][comp]"}>
            <option value="=" selected={@comp == "="}>Equals</option>
            <option value="!=" selected={@comp == "!="}>Not Equals</option>
            <option value="<" selected={@comp == "<"}>Less Than</option>
            <option value=">" selected={@comp == ">"}>Greater Than</option>
            <option value="<=" selected={@comp == "<="}>Less Than/Equal</option>
            <option value=">=" selected={@comp == ">="}>Greater Than/Equal</option>
            <option value="between" selected={@comp == "between"}>Between</option>
            <option value="null" selected={@comp == "null"}>Null</option>
            <option value="not_null" selected={@comp == "not_null"}>Not Null</option>
          </.sc_select_with_slot>
        </label>

        <%= if @comp in ~w(= != < > <= >= between) do %>
          <.sc_input name={"filters[#{@uuid}][value]"} value={@valmap["value"]}/>
          <%= if @comp == "between" do %>
            <span class="text-gray-900 dark:text-gray-100">and</span> <.sc_input name={"filters[#{@uuid}][value2]"} value={@valmap["value2"]}/>
          <% end %>
        <% end %>

          <%!--
          <label>Round to for Comparison
          <select name={"filters[#{@uuid}][precision]]"}>

            <option :for={p <- Enum.to_list(0..5)} value={p} selected={Map.get(@valmap, "precision") == p}><%= p %></option>
          </select>
          </label>
          --%>

      </div>


    """
  end

  def render_form(%{type: :boolean} = assigns) do
    def = assigns.def
    valmap = assigns.filter
    assigns = Map.put(assigns, :valmap, valmap) |> Map.put(:def, def)

    ~H"""
      <div>
        <span class="text-gray-900 dark:text-gray-100"><%= @type %> <%= @def.name %></span>
        <label class="text-gray-900 dark:text-gray-100">Y
          <.sc_input type="radio" name={"filters[#{@uuid}][value]"} checked={@valmap["value"] == "true"} value="true"/>
        </label>
        <label class="text-gray-900 dark:text-gray-100">N
          <.sc_input type="radio" name={"filters[#{@uuid}][value]"} checked={@valmap["value"] != "true"} value="false"/>
        </label>
      </div>
    """
  end


  def render_form(%{type: type} = assigns) when type in [:naive_datetime, :utc_datetime] do
    valmap = assigns.filter
    assigns = Map.put(assigns, :valmap, valmap)

    ### TODO
    # Support shortcuts: today, tomorrow, yesterday, this week, last week, next week, this cal month, last cal month, next cal month,
    # this year, last year, trailing twelve cal months
    # last 7 days, last 30 days, last 90 days,
    # next 7 days, next 30 days, next 90 days,
    # this quarter, next quarter, this quarter last year, last quarter last year
    # YTD, YTD Last year
    # ### How to configure default time zones?

    ~H"""
    <div>
      <label class="text-gray-900 dark:text-gray-100">
        <%= @def.name %>
        <span class="text-gray-900 dark:text-gray-100">After:</span>
        <.sc_input type="datetime-local" step="1" name={"filters[#{@uuid}][value]"} value={reformat_date( @valmap["value"] )}/>
      </label>
      <label class="text-gray-900 dark:text-gray-100">
        <span class="text-gray-900 dark:text-gray-100">Before:</span>
        <.sc_input type="datetime-local" step="1" name={"filters[#{@uuid}][value2]"} value={reformat_date( @valmap["value2"] )}/>
      </label>
    </div>
    """
  end

  def render_form(%{type: :component} = assigns) do
    def = assigns.def
    valmap = assigns.filter
    assigns = Map.put(assigns, :valmap, valmap) |> Map.put(:def, def)

    def.component.(assigns)
  end

  def render_form(%{type: :custom} = assigns) do
    def = assigns.def
    valmap = assigns.filter
    assigns = Map.put(assigns, :valmap, valmap) |> Map.put(:def, def)

    ~H"""
      H: <%= @type %> <%= @filter %>
    """
  end

  def render_form(%{type: :select_options} = assigns) do
    def = assigns.def
    valmap = assigns.filter
    
    # Load options from the option provider
    {options, error_message} = case load_select_options(def) do
      {:ok, opts} -> {opts, nil}
      {:error, :no_provider} -> {[], "No option provider configured"}
      {:error, :provider_error} -> {[], "Error loading options"}
      {:error, reason} -> {[], "Error: #{inspect(reason)}"}
    end
    
    multiple = Map.get(def, :multiple, false)
    searchable = Map.get(def, :searchable, true) and length(options) > 10
    
    assigns = assigns
    |> Map.put(:valmap, valmap)
    |> Map.put(:def, def)
    |> Map.put(:options, options)
    |> Map.put(:error_message, error_message)
    |> Map.put(:multiple, multiple)
    |> Map.put(:searchable, searchable)

    if multiple do
      ~H"""
        <div>
          <%= @def.name %>
          <%= if @error_message do %>
            <div class="text-red-600 text-sm mb-2 p-2 bg-red-50 border border-red-200 rounded">
              <%= @error_message %>
            </div>
          <% end %>
          <%= if @searchable do %>
            <input type="text" placeholder="Search options..." 
                   phx-keyup="search_options" 
                   phx-target={@myself}
                   class="block w-full rounded-md border-gray-300 mb-2"/>
          <% end %>
          <div class="space-y-1 max-h-48 overflow-y-auto">
            <label :for={{value, display} <- @options} class="flex items-center">
              <input name={"filters[#{@uuid}][value][]"}
                id={"filters_#{@uuid}_value_#{value}"}
                type="checkbox"
                value={value}
                checked={Enum.member?(Map.get(@valmap, "value", []) |> List.wrap(), value)}
                class="rounded border-gray-300 mr-2"/>
              <%= display %>
            </label>
          </div>
        </div>
      """
    else
      ~H"""
        <div>
          <label>
            <%= @def.name %>
            <%= if @error_message do %>
              <div class="text-red-600 text-sm mb-2 p-2 bg-red-50 border border-red-200 rounded">
                <%= @error_message %>
              </div>
            <% end %>
            <.sc_select_with_slot name={"filters[#{@uuid}][value]"}>
              <option value="">-- Select --</option>
              <option :for={{value, display} <- @options} 
                      value={value} 
                      selected={@valmap["value"] == value}>
                <%= display %>
              </option>
            </.sc_select_with_slot>
          </label>
        </div>
      """
    end
  end

  def render_form(%{type: {:parameterized, Ecto.Enum, typemap}} = assigns) do
    assigns = Map.put(assigns, :values, typemap.mappings)
    valmap = assigns.filter

    assigns = Map.put(assigns, :valmap, valmap)

    ~H"""
      <div>
        <%= @def.name %>
        <label :for={{_a, v} <- @values}>
          <input name={"filters[#{@uuid}][value][]"}
            id={"filters_#{@uuid}_value_#{v}"}
            type="checkbox"
            value={v}
            checked={ Enum.member?(Map.get(@valmap, "value", []) |> List.wrap(), v) }/>
          <%= v %>
        </label>

      </div>
    """
  end

  defp reformat_date(date) when is_binary(date) do
    String.replace(date, ~r/Z/, "")
  end

  defp reformat_date(date) do
    date
  end

  # Load options for select filters
  defp load_select_options(%{option_provider: provider}) do
    try do
      Selecto.OptionProvider.load_options(provider)
    rescue
      _error -> {:error, :provider_error}
    end
  end
  defp load_select_options(_def), do: {:error, :no_provider}

end
