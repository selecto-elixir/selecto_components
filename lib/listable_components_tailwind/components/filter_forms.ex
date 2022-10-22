defmodule ListableComponentsTailwind.Components.FilterForms do
  use Phoenix.LiveComponent

  def render(assigns) do
    filter_def = Map.get(assigns.columns, assigns.filter)
    #  Map.get(assigns.filters(filter))

    type = filter_def.type
    assigns = assign(assigns, type: type, def: filter_def)


    ~H"""
      <div>
        <input name={"filters[#{@uuid}][filter]"} type="hidden" value={@filter}/>
        <input name={"filters[#{@uuid}][section]"} type="hidden" value={@section}/>

        <%= @filter %>
        <%= case @type do %>
          <% :id -> %>
            <%= render_id_form( %{id: @id, filter: @filter, def: @def, value: @value} ) %>
          <% :float -> %>
            <%= render_float_form( %{id: @id, filter: @filter, def: @def, value: @value} ) %>
          <% :decimal -> %>
            <%= render_decimal_form( %{id: @id, filter: @filter, def: @def, value: @value} ) %>
          <% :string -> %>
            <%= render_string_form( %{id: @id, filter: @filter, def: @def, value: @value} ) %>
          <% :integer -> %>
            <%= render_integer_form( %{id: @id, filter: @filter, def: @def, value: @value} ) %>
          <% x when x in [:naive_datetime, :utc_datetime] -> %>
            <%= render_datetime_form( %{id: @id, filter: @filter, def: @def, value: @value} ) %>
          <% :boolean -> %>
            <%= render_boolean_form( %{id: @id, filter: @filter, def: @def, value: @value} ) %>

        <% end %>
      </div>
    """
  end

  def render_id_form(assigns) do  ### if we were provided with a fn to get possible values, show a multi-select
    ~H"""
      ID FORM
    """
  end


  def render_custom_form(assigns) do  ### Filter definition has provided a custom form!
    ~H"""
      Custom FORM
    """
  end

  def render_string_form(assigns) do   ### let them enter strings to partial match
    ~H"""
      string FORM
    """
  end


  def render_integer_form(assigns) do
    ~H"""
      INTERGER FORM
    """
  end

  def render_decimal_form(assigns) do ### let them do <= >= and between..
    ~H"""
      Decimal FORM
    """
  end

  def render_float_form(assigns) do ### let them do <= >= and between..
    ~H"""
      Float FORM
    """
  end

  def render_datetime_form(assigns) do ### Let them pick 'today' 'yesterday' etc or enter a start and/or end date
    ~H"""
      datetime FORM
    """
  end

  def render_boolean_form(assigns) do
    ~H"""
      BOOL FORM
    """
  end



end
