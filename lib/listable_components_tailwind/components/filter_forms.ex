defmodule ListableComponentsTailwind.Components.FilterForms do
  use Phoenix.LiveComponent
  import ListableComponentsTailwind.Components.Common

  def render(assigns) do
    filter_def = Map.get(assigns.columns, assigns.filter["filter"])
    #  Map.get(assigns.filters(filter))

    type = filter_def.type
    assigns = assign(assigns, type: type, def: filter_def)

    ~H"""
      <div>
        <input name={"filters[#{@uuid}][filter]"} type="hidden" value={@filter["filter"]}/>
        <input name={"filters[#{@uuid}][section]"} type="hidden" value={@section}/>
        <input name={"filters[#{@uuid}][index]"} type="hidden" value={@index}/>


        <%= render_form(%{type: @type, uuid: @uuid, id: @id, filter: @filter, def: @def} ) %>
        TODO: SHOW ERRORS
        TODO: button to remove item

      </div>
    """
  end


  def render_form(%{type: :string} = assigns) do
    def = assigns.def
    valmap = assigns.filter
    IO.inspect(valmap)
    assigns = Map.put(assigns, :valmap, valmap)

    ~H"""
      <div>
        <label>
          <%= def.name %>
          <select name={"filters[#{@uuid}][comp]"}>
            <option value="=" selected={Map.get(@valmap, "comp") == "="}>Equals</option>
            <option value="!=" selected={Map.get(@valmap, "comp") == "!="}>Not Equals</option>
            <option value="starts" selected={Map.get(@valmap, "comp") == "starts"}>Starts With</option>
            <option value="ends" selected={Map.get(@valmap, "comp") == "ends"}>Ends With</option>
            <option value="contains" selected={Map.get(@valmap, "comp") == "contains"}>Contains</option>

          </select>
          <.input name={"filters[#{@uuid}][value]"} value={@valmap["value"]}/>
          <!-- <label><input type="checkbox" name={"filters[#{@uuid}][ignore_case]"} value="Y"/>Ignore Case</label> -->
        </label>
      </div>
    """
  end


  def render_form(%{type: t} = assigns) when t in [:id, :integer]do
    def = assigns.def
    valmap = assigns.filter
    assigns = Map.put(assigns, :valmap, valmap)

    ~H"""
      <div>

        <label>
          <%= def.name %>
          <select name={"filters[#{@uuid}][comp]"}>
            <option value="=" selected={Map.get(@valmap, "comp") == "="}>Equals</option>
            <option value="=" selected={Map.get(@valmap, "comp") == "!="}>Not Equals</option>
            <option value="=" selected={Map.get(@valmap, "comp") == "<"}>Less Than</option>
            <option value="=" selected={Map.get(@valmap, "comp") == ">"}>Greater Than</option>
            <option value="=" selected={Map.get(@valmap, "comp") == "<="}>Less Than/Equal</option>
            <option value="=" selected={Map.get(@valmap, "comp") == ">="}>Greater Than/Equal</option>
            <option value="between" selected={Map.get(@valmap, "comp") == "between"}>Between</option>
          </select>
          <.input name={"filters[#{@uuid}][value]"} value={@valmap["value"]}/>
          <.input name={"filters[#{@uuid}][value2]"} value={@valmap["value2"]}/>

        </label>
      </div>
    """
  end

  def render_form(%{type: t} = assigns) when t in [:decimal, :float] do
    def = assigns.def
    valmap = assigns.filter
    assigns = Map.put(assigns, :valmap, valmap)
    ~H"""
      <div>
        <label>
          <%= def.name %>
          <select name={"filters[#{@uuid}][comp]"}>
            <option value="=" selected={Map.get(@valmap, "comp") == "="}>Equals</option>
            <option value="!=" selected={Map.get(@valmap, "comp") == "!="}>Not Equals</option>
            <option value="<" selected={Map.get(@valmap, "comp") == "<"}>Less Than</option>
            <option value=">" selected={Map.get(@valmap, "comp") == ">"}>Greater Than</option>
            <option value="<=" selected={Map.get(@valmap, "comp") == "<="}>Less Than/Equal</option>
            <option value=">=" selected={Map.get(@valmap, "comp") == ">="}>Greater Than/Equal</option>
            <option value="between" selected={Map.get(@valmap, "comp") == "between"}>Between</option>
          </select>
          <.input name={"filters[#{@uuid}][value]"} value={@valmap["value"]}/>
          <.input name={"filters[#{@uuid}][value2]"} value={@valmap["value2"]}/>
          <%!--
          <label>Round to for Comparison
          <select name={"filters[#{@uuid}][precision]]"}>

            <option :for={p <- Enum.to_list(0..5)} value={p} selected={Map.get(@valmap, "precision") == p}><%= p %></option>
          </select>
          </label>
          --%>

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

  def render_form(%{type: :custom} = assigns) do
    def = assigns.def

    ~H"""
      H: <%= @type %> <%= @filter %>
    """
  end
end
