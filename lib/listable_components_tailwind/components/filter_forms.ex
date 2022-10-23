defmodule ListableComponentsTailwind.Components.FilterForms do
  use Phoenix.LiveComponent
  import ListableComponentsTailwind.Components.Common

  def render(assigns) do
    filter_def = Map.get(assigns.columns, assigns.filter)
    #  Map.get(assigns.filters(filter))

    type = filter_def.type
    assigns = assign(assigns, type: type, def: filter_def)


    ~H"""
      <div>
        <input name={"filters[#{@uuid}][filter]"} type="hidden" value={@filter}/>
        <input name={"filters[#{@uuid}][section]"} type="hidden" value={@section}/>

        <%= render_form(%{type: @type, uuid: @uuid, id: @id, filter: @filter, def: @def, value: @value} ) %>

      </div>
    """
  end

  def render_form(%{type: :id} = assigns) do
    def = assigns.def
    ~H"""
      <div>
        <label>
          <%= @type %> <%= @filter %>
          <.input name={"filters[#{@uuid}][value]"} value={@value}/>
        </label>
      </div>
    """
  end

  def render_form(%{type: :string} = assigns) do
    def = assigns.def
    ~H"""
      <div>
        <label>
          <%= @type %> <%= @filter %>
          <.input name={"filters[#{@uuid}][value]"} value={@value}/>
        </label>
      </div>
    """
  end

  def render_form(%{type: :float} = assigns) do
    def = assigns.def
    ~H"""
      <div>
        <label>
          <%= @type %> <%= @filter %>
          <.input name={"filters[#{@uuid}][value]"} value={@value}/>
        </label>
      </div>
    """
  end

  def render_form(%{type: :integer} = assigns) do
    def = assigns.def
    ~H"""
      <div>
        <label>
          <%= @type %> <%= @filter %>
          <.input name={"filters[#{@uuid}][value]"} value={@value}/>
        </label>
      </div>
    """
  end

  def render_form(%{type: :decimal} = assigns) do
    def = assigns.def
    ~H"""
      <div>
        <label>
          <%= @type %> <%= @filter %>
          <.input name={"filters[#{@uuid}][value]"} value={@value}/>
        </label>
      </div>
    """
  end

  def render_form(%{type: :boolean} = assigns) do
    def = assigns.def
    ~H"""
      <div>
        <label>
          <%= @type %> <%= @filter %>
          <.input name={"filters[#{@uuid}][value]"} value={@value}/>
        </label>
      </div>
    """
  end


  def render_form(%{type: type} = assigns) when type in [:naive_datetime, :utc_datetime] do
    def = assigns.def
    ~H"""
      G: <%= @type %> <%= @filter %>

    """
  end

  def render_form(%{type: :custom} =assigns) do
    def = assigns.def
    ~H"""
      H: <%= @type %> <%= @filter %>
    """
  end



end
