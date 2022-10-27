defmodule ListableComponentsTailwind.Components.DetailTable do
  @doc """
    Display results of a detail view

  """

  use Phoenix.LiveComponent

  def render(assigns) do
    {results, aliases} = Listable.execute(assigns.listable)

    selected = assigns.listable.set.selected
    IO.inspect(selected, label: "Selecetd")
    selected = Enum.map( selected, fn
      {a, f} = sel->
        {sel, assigns.listable.config.columns[f]}
      f ->
        {f, assigns.listable.config.columns[f]}
    end)

    fmap = Enum.zip(aliases, selected ) |> Enum.into(%{})

    assigns = assign(assigns, fmap: fmap, results: results, aliases: aliases)


    ~H"""
    <div>
      <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200 dark:ring-0 divide-gray-200 rounded-sm table-auto dark:divide-y-0 dark:divide-gray-800 sm:rounded">
        <tr>
          <th :for={r <- @aliases} class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50 dark:bg-gray-600 dark:text-gray-300">
            <%= r %>
          </th>
        </tr>
        <tr :for={r <- @results} class="border-b dark:border-gray-700 bg-white even:bg-white dark:bg-gray-700 dark:even:bg-gray-800 last:border-none">
          <td :for={c <- @aliases} class="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
            <%= with {sel, def} <- @fmap[c] do %>
              <% IO.inspect(def) %>
              <%= case def do %>
                <% %{format: fmt_fun} = def when is_function(fmt_fun) -> %>
                  AAA <%= r[c] %>
                <% _ -> %>
                  BBB <%= r[c] %>
              <%= end %>
            <%= end %>
          </td>
        </tr>
      </table>
    </div>
    """
  end


end
