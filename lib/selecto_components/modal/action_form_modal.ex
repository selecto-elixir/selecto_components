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

    applied? = applied_result?(Map.get(assigns, :last_result))
    disabled? = disabled_action?(action)
    controls_disabled? = disabled? || applied?

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
      |> assign(:applied?, applied?)
      |> assign(:disabled?, disabled?)
      |> assign(:controls_disabled?, controls_disabled?)
      |> assign(:disabled_reason, disabled_reason(action))
      |> assign(:action_status, action_status(disabled?, applied?))
      |> assign(:result_summary, result_summary(Map.get(assigns, :last_result)))

    ~H"""
    <div
      data-selecto-action-form-modal
      data-action-id={Map.get(@action, :id) || Map.get(@action, "id")}
      data-action-capability={Map.get(@action, :capability) || Map.get(@action, "capability")}
      data-action-operation={Map.get(@action, :operation) || Map.get(@action, "operation")}
      data-action-scope={Map.get(@action, :scope) || Map.get(@action, "scope")}
      data-action-status={@action_status}
      data-action-submitting={@submitting}
      aria-busy={not is_nil(@submitting)}
      class="space-y-4"
    >
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
            <select
              :if={select_input?(input)}
              data-selecto-action-form-input={Map.get(input, "id")}
              name={"inputs[#{Map.get(input, "id")}]"}
              required={required_html_input?(input)}
              aria-required={input_required?(input)}
              disabled={@controls_disabled?}
              class="mt-1 w-full rounded border border-slate-300 px-3 py-2 text-sm"
            >
              <option :for={option <- input_options(input)} value={option_value(option)} selected={option_selected?(option, input, @form_inputs)}>
                {option_label(option)}
              </option>
            </select>
            <textarea
              :if={textarea_input?(input)}
              data-selecto-action-form-input={Map.get(input, "id")}
              name={"inputs[#{Map.get(input, "id")}]"}
              rows={input_rows(input)}
              required={required_html_input?(input)}
              aria-required={input_required?(input)}
              disabled={@controls_disabled?}
              class="mt-1 w-full rounded border border-slate-300 px-3 py-2 text-sm"
            ><%= Map.get(@form_inputs, Map.get(input, "id"), "") %></textarea>
            <input
              :if={!select_input?(input) && !textarea_input?(input)}
              data-selecto-action-form-input={Map.get(input, "id")}
              name={"inputs[#{Map.get(input, "id")}]"}
              value={Map.get(@form_inputs, Map.get(input, "id"), "")}
              type={input_type(input)}
              checked={input_checked?(input, @form_inputs)}
              required={required_html_input?(input)}
              aria-required={input_required?(input)}
              disabled={@controls_disabled?}
              class={input_class(input)}
            />
          </label>
        </div>

        <label :if={truthy?(Map.get(@confirmation, "required"))} class="flex items-start gap-2 rounded border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
          <input
            type="checkbox"
            name="confirmed"
            value="true"
            checked={@confirmed}
            disabled={@controls_disabled?}
            class="mt-0.5"
          />
          <span>{Map.get(@confirmation, "message") || "Confirm this action before applying."}</span>
        </label>

        <details class="text-xs text-slate-600">
          <summary class="cursor-pointer font-medium text-slate-700">Request template</summary>
          <pre class="mt-2 max-h-48 overflow-auto rounded bg-slate-950 p-3 text-slate-100"><%= Jason.encode!(@request_template, pretty: true) %></pre>
        </details>

        <div :if={@last_error} data-selecto-action-form-error class="rounded border border-rose-200 bg-rose-50 p-3 text-sm text-rose-800">
          {@last_error}
        </div>

        <div :if={@disabled?} data-selecto-action-form-disabled class="rounded border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
          {@disabled_reason || "This action is not available for the selected target."}
        </div>

        <div :if={@last_result} data-selecto-action-form-result class="rounded border border-emerald-200 bg-emerald-50 p-3 text-xs text-emerald-900">
          <div class="mb-1 font-semibold">{result_title(@last_result)}</div>
          <dl :if={@result_summary != []} data-selecto-action-form-result-summary class="mb-3 grid gap-2 text-sm sm:grid-cols-2">
            <div :for={item <- @result_summary} data-selecto-action-form-result-summary-item={item.key} class="rounded bg-white/70 p-2 ring-1 ring-emerald-100">
              <dt class="text-[11px] font-semibold uppercase text-emerald-700">{item.label}</dt>
              <dd class="mt-1 font-mono text-xs text-emerald-950">{item.value}</dd>
            </div>
          </dl>
          <details data-selecto-action-form-result-details class="mt-2">
            <summary class="cursor-pointer font-medium text-emerald-800">Response details</summary>
            <pre class="mt-2 max-h-56 overflow-auto rounded bg-white/70 p-2 text-emerald-950 ring-1 ring-emerald-100"><%= Jason.encode!(@last_result, pretty: true) %></pre>
          </details>
        </div>

        <div :if={@applied?} data-selecto-action-form-applied class="rounded border border-slate-200 bg-slate-50 p-3 text-sm text-slate-700">
          This action has been applied. Reopen the row to run another action request.
        </div>

        <div class="flex justify-end gap-2">
          <button
            :if={(@last_result || @last_error) && !@applied?}
            type="button"
            phx-click="reset_action_form"
            phx-target={@myself}
            data-selecto-action-form-reset
            class="rounded border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50"
          >
            Clear result
          </button>
          <button
            type="submit"
            name="intent"
            value="preview"
            data-selecto-action-form-submit="preview"
            class="rounded bg-indigo-600 px-3 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
            disabled={@disabled? || @applied? || @submitting == "preview"}
          >
            Preview
          </button>
          <button
            type="submit"
            name="intent"
            value="apply"
            data-selecto-action-form-submit="apply"
            class="rounded bg-emerald-600 px-3 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
            disabled={apply_disabled?(@confirmation, @confirmed, @submitting, @applied?, @disabled?)}
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
       confirmed: truthy?(Map.get(params, "confirmed")),
       last_error: nil
     )}
  end

  def handle_event("reset_action_form", _params, socket) do
    if applied_result?(Map.get(socket.assigns, :last_result)) do
      {:noreply, socket}
    else
      {:noreply,
       assign(socket,
         submitting: nil,
         last_request: nil,
         last_result: nil,
         last_error: nil
       )}
    end
  end

  def handle_event("submit_action_form", params, socket) do
    intent = normalize_intent(Map.get(params, "intent"))
    action = normalize_action(socket.assigns.action)
    target = normalize_target(socket.assigns)

    inputs =
      params |> Map.get("inputs", %{}) |> normalize_inputs(Map.get(socket.assigns, :inputs, []))

    confirmed = truthy?(Map.get(params, "confirmed"))

    case validate_required_inputs(inputs, Map.get(socket.assigns, :inputs, [])) do
      :ok ->
        submit_action_request(socket, action, target, intent, inputs, confirmed)

      {:error, message} ->
        {:noreply,
         assign(socket,
           form_inputs: inputs,
           confirmed: confirmed,
           submitting: nil,
           last_error: message
         )}
    end
  end

  defp submit_action_request(socket, action, target, intent, inputs, confirmed) do
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
    input_defs = List.wrap(input_defs)

    normalized_defined =
      Map.new(input_defs, fn input ->
        id = Map.get(input, "id")
        {id, normalize_input_value(Map.get(inputs, id), input)}
      end)

    defined_ids =
      input_defs
      |> Enum.map(&Map.get(&1, "id"))
      |> MapSet.new()

    inputs
    |> Enum.reject(fn {key, _value} -> is_nil(key) or MapSet.member?(defined_ids, key) end)
    |> Map.new()
    |> Map.merge(normalized_defined)
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

  defp input_type(%{"type" => type}) when type in ["email", "url", "date", "time"],
    do: type

  defp input_type(%{"type" => type}) when type in ["datetime", "datetime-local"],
    do: "datetime-local"

  defp input_type(_input), do: "text"

  defp input_class(%{"type" => "boolean"}),
    do: "mt-1 rounded border border-slate-300 text-sm"

  defp input_class(_input),
    do: "mt-1 w-full rounded border border-slate-300 px-3 py-2 text-sm"

  defp required_html_input?(input), do: input_required?(input) and input_type(input) != "checkbox"

  defp input_required?(input), do: truthy?(Map.get(input, "required"))

  defp select_input?(input), do: input_options(input) != []

  defp textarea_input?(input) do
    input
    |> Map.get("type")
    |> to_string()
    |> Kernel.in(["text", "textarea", "long_text"])
  end

  defp input_options(input) do
    input
    |> input_option_source()
    |> List.wrap()
    |> Enum.reject(&is_nil/1)
  end

  defp input_option_source(input) do
    Map.get(input, "options") ||
      Map.get(input, "choices") ||
      Map.get(input, "values") ||
      input
      |> Map.get("raw", %{})
      |> then(fn raw ->
        Map.get(raw, "options") || Map.get(raw, "choices") || Map.get(raw, "values") || []
      end)
  end

  defp input_rows(input) do
    Map.get(input, "rows") || get_in(input, ["raw", "rows"]) || 4
  end

  defp option_selected?(option, input, form_inputs) do
    current_value =
      form_inputs
      |> Map.get(Map.get(input, "id"), Map.get(input, "default", ""))
      |> to_string()

    option_value(option) == current_value
  end

  defp option_value(%{"value" => value}), do: to_string(value)
  defp option_value(%{value: value}), do: to_string(value)
  defp option_value(%{"id" => value}), do: to_string(value)
  defp option_value(%{id: value}), do: to_string(value)
  defp option_value({value, _label}), do: to_string(value)
  defp option_value(value), do: to_string(value)

  defp option_label(%{"label" => label}), do: label
  defp option_label(%{label: label}), do: label
  defp option_label(%{"name" => label}), do: label
  defp option_label(%{name: label}), do: label
  defp option_label({_value, label}), do: label
  defp option_label(value), do: humanize(value)

  defp input_checked?(%{"type" => "boolean"} = input, form_inputs) do
    form_inputs
    |> Map.get(Map.get(input, "id"))
    |> truthy?()
  end

  defp input_checked?(_input, _form_inputs), do: false

  defp validate_required_inputs(inputs, input_defs) do
    missing =
      input_defs
      |> List.wrap()
      |> Enum.filter(&input_required?/1)
      |> Enum.filter(fn input ->
        inputs
        |> Map.get(Map.get(input, "id"))
        |> blank_input_value?()
      end)
      |> Enum.map(&input_label/1)

    case missing do
      [] -> :ok
      labels -> {:error, "Required inputs missing: #{Enum.join(labels, ", ")}."}
    end
  end

  defp blank_input_value?(value) when value in [nil, ""], do: true
  defp blank_input_value?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank_input_value?(value) when is_list(value), do: value == []
  defp blank_input_value?(_value), do: false

  defp input_label(input), do: Map.get(input, "label") || humanize(Map.get(input, "id"))

  defp humanize(nil), do: "Input"

  defp humanize(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp truthy?(value) when value in [true, "true", "1", 1, :yes], do: true
  defp truthy?(_value), do: false

  defp apply_disabled?(confirmation, confirmed, submitting, applied?, disabled?) do
    disabled? or applied? or submitting == "apply" or
      (truthy?(Map.get(confirmation, "required")) and not confirmed)
  end

  defp disabled_action?(action) do
    Map.get(action, "disabled?") == true or Map.get(action, "status") == "disabled"
  end

  defp action_status(_disabled?, true), do: "applied"
  defp action_status(true, _applied?), do: "disabled"
  defp action_status(_disabled?, _applied?), do: "enabled"

  defp disabled_reason(action) do
    Map.get(action, "reason") || Map.get(action, "disabled_reason")
  end

  defp applied_result?(%{"intent" => "apply"}), do: true
  defp applied_result?(%{intent: "apply"}), do: true
  defp applied_result?(_result), do: false

  defp result_title(%{"intent" => "apply"}), do: "Apply result"
  defp result_title(%{intent: "apply"}), do: "Apply result"
  defp result_title(_result), do: "Preview result"

  defp result_summary(nil), do: []

  defp result_summary(result) do
    payload = result_payload(result)

    [
      summary_item(
        "action",
        "Action",
        first_present([map_value(payload, "action"), get_in(payload, ["preview", "action"])])
      ),
      summary_item(
        "mode",
        "Mode",
        first_present([get_in(payload, ["result", "mode"]), map_value(payload, "mode")])
      ),
      summary_item(
        "changes",
        "Changes",
        first_present([map_value(payload, "changes"), get_in(payload, ["preview", "changes"])])
      ),
      record_summary_item(
        first_present([get_in(payload, ["result", "record"]), map_value(payload, "record")])
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp record_summary_item(nil), do: nil

  defp record_summary_item(records) when is_list(records) do
    summary_item("records", "Records", "#{length(records)} records")
  end

  defp record_summary_item(record), do: summary_item("record", "Record", record)

  defp result_payload(result) when is_map(result) do
    map_value(result, "payload", result)
  end

  defp result_payload(_result), do: %{}

  defp summary_item(_key, _label, nil), do: nil

  defp summary_item(key, label, value) do
    %{key: key, label: label, value: summary_value(value)}
  end

  defp summary_value(value) when is_map(value) or is_list(value), do: Jason.encode!(value)
  defp summary_value(value), do: to_string(value)

  defp first_present(values), do: Enum.find(values, &(not is_nil(&1)))

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map) and is_binary(key),
    do: Map.get(map, key, Map.get(map, safe_existing_atom(key), default))

  defp map_value(map, key, default) when is_map(map), do: Map.get(map, key, default)
  defp map_value(_map, _key, default), do: default

  defp safe_existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
