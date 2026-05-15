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
       record: %{},
       form_inputs: %{},
       confirmed: false,
       submitting: nil,
       last_request: nil,
       last_result: nil,
       last_error: nil
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
    inputs = Map.get(action, :inputs, Map.get(action, "inputs", []))
    form_inputs = Map.get(assigns, :form_inputs, %{})
    request_inputs = form_inputs |> merge_default_inputs(action) |> normalize_inputs(inputs)

    request_template =
      Actions.request_template(action,
        target: target,
        inputs: request_inputs,
        confirmed: truthy?(Map.get(assigns, :confirmed))
      )

    assigns =
      assigns
      |> assign(:action, action)
      |> assign(:target, target)
      |> assign(:request_template, request_template)
      |> assign(:inputs, inputs)
      |> assign(:form_inputs, request_inputs)
      |> assign(
        :confirmation,
        Map.get(action, :confirmation, Map.get(action, "confirmation", %{}))
      )
      |> assign(:confirmed, truthy?(Map.get(assigns, :confirmed)))
      |> assign_new(:last_result, fn -> nil end)
      |> assign_new(:last_error, fn -> nil end)
      |> assign_new(:submitting, fn -> nil end)
      |> assign(:applied?, applied_result?(Map.get(assigns, :last_result)))

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

      <form
        id={"#{@id}-form"}
        phx-change="change_action_form"
        phx-submit="submit_action_form"
        phx-target={@myself}
        class="space-y-4"
      >
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
              value={Map.get(@form_inputs, Map.get(input, "id"), "")}
              type={input_type(input)}
              checked={input_checked?(input, @form_inputs)}
              class="mt-1 w-full rounded border border-slate-300 px-3 py-2 text-sm"
            />
          </label>
        </div>

        <label :if={truthy?(Map.get(@confirmation, "required"))} class="flex items-start gap-2 rounded border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
          <input type="checkbox" name="confirmed" value="true" checked={@confirmed} class="mt-0.5" />
          <span>{Map.get(@confirmation, "message") || "Confirm this action before applying."}</span>
        </label>

        <details class="text-xs text-slate-600">
          <summary class="cursor-pointer font-medium text-slate-700">Request template</summary>
          <pre class="mt-2 max-h-48 overflow-auto rounded bg-slate-950 p-3 text-slate-100"><%= Jason.encode!(@request_template, pretty: true) %></pre>
        </details>

        <div :if={@last_error} data-selecto-action-form-error class="rounded border border-rose-200 bg-rose-50 p-3 text-sm text-rose-800">
          {@last_error}
        </div>

        <div :if={@last_result} data-selecto-action-form-result class="rounded border border-emerald-200 bg-emerald-50 p-3 text-xs text-emerald-900">
          <div class="mb-1 font-semibold">{result_title(@last_result)}</div>
          <pre class="max-h-56 overflow-auto"><%= Jason.encode!(@last_result, pretty: true) %></pre>
        </div>

        <div :if={@applied?} data-selecto-action-form-applied class="rounded border border-slate-200 bg-slate-50 p-3 text-sm text-slate-700">
          This action has been applied. Reopen the row to run another action request.
        </div>

        <div class="flex justify-end gap-2">
          <button
            type="submit"
            name="intent"
            value="preview"
            class="rounded bg-indigo-600 px-3 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
            disabled={@applied? || @submitting == "preview"}
          >
            Preview
          </button>
          <button
            type="submit"
            name="intent"
            value="apply"
            class="rounded bg-emerald-600 px-3 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
            disabled={apply_disabled?(@confirmation, @confirmed, @submitting, @applied?)}
          >
            Apply
          </button>
        </div>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("change_action_form", params, socket) do
    {:noreply,
     assign(socket,
       form_inputs: Map.get(params, "inputs", %{}),
       confirmed: truthy?(Map.get(params, "confirmed"))
     )}
  end

  def handle_event("submit_action_form", params, socket) do
    intent = normalize_intent(Map.get(params, "intent"))
    action = normalize_action(socket.assigns.action)
    target = normalize_target(socket.assigns)

    inputs =
      params |> Map.get("inputs", %{}) |> normalize_inputs(Map.get(socket.assigns, :inputs, []))

    confirmed = truthy?(Map.get(params, "confirmed"))

    request =
      Actions.request_template(action,
        target: target,
        inputs: inputs,
        dry_run: intent == "preview",
        confirmed: confirmed
      )

    payload = %{
      intent: intent,
      action_id: Map.get(action, "id"),
      action: action,
      target: target,
      record: socket.assigns.record,
      endpoint: endpoint_for(action, intent),
      request: request
    }

    send(self(), {:selecto_action_form_submit, payload})

    {:noreply,
     assign(socket,
       form_inputs: inputs,
       confirmed: confirmed,
       submitting: intent,
       last_request: request,
       last_error: nil
     )}
  end

  defp normalize_action(action) when is_map(action),
    do: SelectoComponents.QueryContract.json_safe(action)

  defp normalize_action(_action), do: %{}

  defp normalize_intent("apply"), do: "apply"
  defp normalize_intent(_intent), do: "preview"

  defp normalize_target(assigns) do
    explicit = Map.get(assigns, :target, %{})
    record = Map.get(assigns, :record, %{})

    (explicit || %{})
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> Map.put_new("id", Map.get(record, "id", Map.get(record, :id)))
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp merge_default_inputs(inputs, action) when is_map(inputs) do
    action
    |> Actions.request_template()
    |> Map.get("inputs", %{})
    |> Map.merge(inputs)
  end

  defp merge_default_inputs(_inputs, action) do
    action
    |> Actions.request_template()
    |> Map.get("inputs", %{})
  end

  defp normalize_inputs(inputs, input_defs) when is_map(inputs) do
    input_defs
    |> List.wrap()
    |> Map.new(fn input ->
      id = Map.get(input, "id")
      {id, normalize_input_value(Map.get(inputs, id), input)}
    end)
    |> Map.merge(Map.drop(inputs, [nil]))
    |> Enum.reject(fn {key, _value} -> is_nil(key) end)
    |> Map.new()
  end

  defp normalize_inputs(_inputs, _input_defs), do: %{}

  defp normalize_input_value(nil, %{"type" => "boolean"}), do: false
  defp normalize_input_value("true", %{"type" => "boolean"}), do: true
  defp normalize_input_value("false", %{"type" => "boolean"}), do: false
  defp normalize_input_value(value, %{"type" => "boolean"}), do: truthy?(value)
  defp normalize_input_value(nil, input), do: Map.get(input, "default", "")
  defp normalize_input_value(value, _input), do: value

  defp endpoint_for(action, intent) do
    action
    |> Map.get("endpoints", %{})
    |> Map.get(intent, %{})
  end

  defp input_type(%{"type" => "boolean"}), do: "checkbox"

  defp input_type(%{"type" => type}) when type in ["integer", "number", "float", "decimal"],
    do: "number"

  defp input_type(_input), do: "text"

  defp input_checked?(%{"type" => "boolean"} = input, form_inputs) do
    form_inputs
    |> Map.get(Map.get(input, "id"))
    |> truthy?()
  end

  defp input_checked?(_input, _form_inputs), do: false

  defp humanize(nil), do: "Input"

  defp humanize(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp truthy?(value) when value in [true, "true", "1", 1, :yes], do: true
  defp truthy?(_value), do: false

  defp apply_disabled?(confirmation, confirmed, submitting, applied?) do
    applied? or submitting == "apply" or
      (truthy?(Map.get(confirmation, "required")) and not confirmed)
  end

  defp applied_result?(%{"intent" => "apply"}), do: true
  defp applied_result?(%{intent: "apply"}), do: true
  defp applied_result?(_result), do: false

  defp result_title(%{"intent" => "apply"}), do: "Apply result"
  defp result_title(%{intent: "apply"}), do: "Apply result"
  defp result_title(_result), do: "Preview result"
end
