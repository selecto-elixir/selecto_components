defmodule SelectoComponents.Keyboard.ShortcutHelp do
  @moduledoc false

  use Phoenix.Component

  alias SelectoComponents.Theme

  attr(:id, :any, required: true)
  attr(:theme, :map, required: true)
  attr(:groups, :list, default: [])

  def modal(assigns) do
    ~H"""
    <div
      id={"selecto-shortcut-help-#{@id}"}
      data-selecto-shortcut-help
      hidden
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
    >
      <div
        class="absolute inset-0"
        style="background: color-mix(in srgb, black 48%, transparent);"
        data-selecto-shortcut-help-close
      >
      </div>

      <section
        role="dialog"
        aria-modal="true"
        aria-labelledby={"selecto-shortcut-help-title-#{@id}"}
        tabindex="-1"
        data-selecto-shortcut-help-dialog
        class={[
          Theme.slot(@theme, :panel),
          "relative z-10 w-full max-w-2xl border p-4 shadow-xl"
        ]}
        style="border-color: var(--sc-surface-border);"
      >
        <div class="mb-3 flex items-center justify-between gap-3">
          <h2
            id={"selecto-shortcut-help-title-#{@id}"}
            class="text-base font-semibold"
            style="color: var(--sc-text-primary);"
          >
            Keyboard Shortcuts
          </h2>

          <button
            type="button"
            data-selecto-shortcut-help-close
            class={Theme.slot(@theme, :button_secondary)}
          >
            Close
          </button>
        </div>

        <div class="grid gap-4">
          <section :for={group <- @groups}>
            <h3 class="mb-2 text-sm font-semibold" style="color: var(--sc-text-secondary);">
              {group.group}
            </h3>

            <dl class="grid gap-2">
              <div
                :for={shortcut <- group.shortcuts}
                class="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 border-t py-2"
                style="border-color: var(--sc-surface-border);"
              >
                <dt class="text-sm" style="color: var(--sc-text-primary);">
                  {shortcut.label}
                </dt>
                <dd class="flex flex-wrap justify-end gap-1">
                  <kbd
                    :for={key <- shortcut.keys}
                    class="rounded border px-2 py-1 text-xs font-semibold"
                    style="border-color: var(--sc-surface-border); background: var(--sc-surface-muted); color: var(--sc-text-primary);"
                  >
                    {format_key_for_display(key)}
                  </kbd>
                </dd>
              </div>
            </dl>
          </section>
        </div>
      </section>
    </div>
    """
  end

  defp format_key_for_display(key) when is_binary(key) do
    key
    |> String.split(" ", trim: true)
    |> Enum.map(fn combo ->
      combo
      |> String.split("+", trim: true)
      |> Enum.map(&format_key_part/1)
      |> Enum.join(" + ")
    end)
    |> Enum.join(" then ")
  end

  defp format_key_for_display(key), do: to_string(key)

  defp format_key_part("mod"), do: "Cmd/Ctrl"
  defp format_key_part("enter"), do: "Enter"
  defp format_key_part("escape"), do: "Escape"
  defp format_key_part("shift"), do: "Shift"
  defp format_key_part("alt"), do: "Alt"
  defp format_key_part("?"), do: "?"
  defp format_key_part(key), do: String.upcase(key)
end
