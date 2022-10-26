defmodule ListableComponentsTailwind.Components.AggregateTable do
  @doc """
    display results of aggregate view
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    {results, aliases} = Listable.execute(assigns.listable)

    group_by = assigns.listable.set.group_by
    aggregates = assigns.listable.set.selected -- group_by
    assigns = assign(assigns, results: results, aliases: aliases, group_by: group_by, aggregate: aggregates)

    ~H"""
    <div>
      <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200 dark:ring-0 divide-gray-200 rounded-sm table-auto dark:divide-y-0 dark:divide-gray-800 sm:rounded">
        <tr>
          <th :for={g <- @group_by} class="font-bold px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50 dark:bg-gray-600 dark:text-gray-300">
            <%= case g do %>
            <%= {:extract, f, fmt} -> %>
              <%= inspect(f) %>
            <%= f -> %>
              <%= inspect(f)  %>
            <% end %>

          </th>
          <th :for={r <- @aggregate} class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50 dark:bg-gray-600 dark:text-gray-300">
            <%= inspect(r) %>
          </th>
        </tr>
        <tr :for={r <- @results} class="border-b dark:border-gray-700 bg-white even:bg-white dark:bg-gray-700 dark:even:bg-gray-800 last:border-none">
          <td :for={c <- @aliases} class="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
            <%= r[c] %>
          </td>
        </tr>
      </table>
    </div>
    """
  end

end
