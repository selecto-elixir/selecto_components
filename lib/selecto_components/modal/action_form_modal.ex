defmodule SelectoComponents.Modal.ActionFormModal do
  @moduledoc """
  Modal component for rendering a domain action as a form shell.

  Host applications still own action preview/apply execution. This component
  renders the action metadata, target row, request template, inputs, and
  confirmation affordance so Selecto result rows can open action forms through
  the existing detail-action modal path.
  """

  use Phoenix.LiveComponent
  alias SelectoComponents.Actions

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       action: %{},
       target: %{},
       record: %{}
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    action = normalize_action(Map.get(assigns, :action, %{}))
    target = normalize_target(assigns)
    request_template = Actions.request_template(action, target: target)

    assigns =
      assigns
      |> assign(:action, action)
      |> assign(:target, target)
      |> assign(:request_template, request_template)
      |> assign(:inputs, Map.get(action, :inputs, Map.get(action, "inputs", [])))
      |> assign(
        :confirmation,
        Map.get(action, :confirmation, Map.get(action, "confirmation", %{}))
      )

    ~H"""
    <div data-selecto-action-form-modal class="space-y-4">
      <div class="rounded border border-slate-200 bg-slate-50 p-3 text-sm">
        <div class="flex flex-wrap items-center gap-2">
          <span class="font-semibold text-slate-900">{Map.get(@action, :id) || Map.get(@action, "id")}</span>
          <span :if={Map.get(@action, :operation) || Map.get(@action, "operation")} class="rounded bg-white px-2 py-0.5 text-xs text-slate-600 ring-1 ring-slate-200">
            {Map.get(@action, :operation) || Map.get(@action, "operation")}
          </span>
          <span :if={Map.get(@action, :scope) || Map.get(@action, "scope")} class="rounded bg-white px-2 py-0.5 text-xs text-slate-600 ring-1 ring-slate-200">
            {Map.get(@action, :scope) || Map.get(@action, "scope")}
          </span>
        </div>
        <p :if={Map.get(@action, :capability) || Map.get(@action, "capability")} class="mt-1 font-mono text-xs text-slate-500">
          {Map.get(@action, :capability) || Map.get(@action, "capability")}
        </p>
      </div>

      <div data-selecto-action-form-target class="rounded border border-slate-200 p-3">
        <h4 class="text-sm font-semibold text-slate-900">Target</h4>
        <dl class="mt-2 grid gap-2 text-sm sm:grid-cols-2">
          <div :for={{key, value} <- @target}>
            <dt class="text-xs uppercase text-slate-500">{key}</dt>
            <dd class="font-medium text-slate-800">{inspect(value)}</dd>
          </div>
        </dl>
      </div>

      <div data-selecto-action-form-inputs class="space-y-3">
        <h4 class="text-sm font-semibold text-slate-900">Inputs</h4>
        <p :if={@inputs == []} class="text-sm text-slate-500">This action has no additional inputs.</p>
        <label :for={input <- @inputs} class="block">
          <span class="text-sm font-medium text-slate-700">
            {Map.get(input, "label") || humanize(Map.get(input, "id"))}
            <span :if={truthy?(Map.get(input, "required"))} class="text-rose-600">*</span>
          </span>
          <input
            name={"inputs[#{Map.get(input, "id")}]"}
            value={Map.get(@request_template["inputs"] || %{}, Map.get(input, "id"), "")}
            type={input_type(input)}
            class="mt-1 w-full rounded border border-slate-300 px-3 py-2 text-sm"
          />
        </label>
      </div>

      <label :if={truthy?(Map.get(@confirmation, "required"))} class="flex items-start gap-2 rounded border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
        <input type="checkbox" name="confirmed" value="true" class="mt-0.5" />
        <span>{Map.get(@confirmation, "message") || "Confirm this action before applying."}</span>
      </label>

      <details class="text-xs text-slate-600">
        <summary class="cursor-pointer font-medium text-slate-700">Request template</summary>
        <pre class="mt-2 max-h-48 overflow-auto rounded bg-slate-950 p-3 text-slate-100"><%= Jason.encode!(@request_template, pretty: true) %></pre>
      </details>

      <div class="flex justify-end gap-2">
        <button type="button" class="rounded bg-indigo-600 px-3 py-2 text-sm font-medium text-white opacity-70" disabled>
          Preview
        </button>
        <button type="button" class="rounded bg-emerald-600 px-3 py-2 text-sm font-medium text-white opacity-70" disabled>
          Apply
        </button>
      </div>
    </div>
    """
  end

  defp normalize_action(action) when is_map(action),
    do: SelectoComponents.QueryContract.json_safe(action)

  defp normalize_action(_action), do: %{}

  defp normalize_target(assigns) do
    explicit = Map.get(assigns, :target, %{})
    record = Map.get(assigns, :record, %{})

    (explicit || %{})
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> Map.put_new("id", Map.get(record, "id", Map.get(record, :id)))
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp input_type(%{"type" => "boolean"}), do: "checkbox"

  defp input_type(%{"type" => type}) when type in ["integer", "number", "float", "decimal"],
    do: "number"

  defp input_type(_input), do: "text"

  defp humanize(nil), do: "Input"

  defp humanize(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp truthy?(value) when value in [true, "true", "1", 1, :yes], do: true
  defp truthy?(_value), do: false
end
