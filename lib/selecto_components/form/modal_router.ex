defmodule SelectoComponents.Form.ModalRouter do
  use Phoenix.Component

  attr(:visible, :boolean, default: false)
  attr(:detail_modal_component, :any, default: nil)
  attr(:modal_detail_data, :map, default: %{})

  def router(assigns) do
    ~H"""
    <%= if @visible do %>
      <%= if @detail_modal_component do %>
        <.live_component
          module={@detail_modal_component}
          id="detail-modal"
          detail_data={@modal_detail_data}
        />
      <% else %>
        <%= case Map.get(@modal_detail_data, :action_type, :modal) do %>
          <% :iframe_modal -> %>
            <.live_component
              module={SelectoComponents.Modal.IframeModal}
              id="detail-modal"
              record={@modal_detail_data.record}
              current_index={@modal_detail_data.current_index}
              total_records={@modal_detail_data.total_records}
              records={@modal_detail_data.records}
              title={Map.get(@modal_detail_data, :title, "Preview")}
              title_template={Map.get(@modal_detail_data, :title_template)}
              iframe_url={Map.get(@modal_detail_data, :iframe_url)}
              url_template={Map.get(@modal_detail_data, :url_template)}
              iframe_allow={Map.get(@modal_detail_data, :iframe_allow)}
              iframe_referrer_policy={Map.get(@modal_detail_data, :iframe_referrer_policy)}
              iframe_sandbox={Map.get(@modal_detail_data, :iframe_sandbox)}
              size={Map.get(@modal_detail_data, :size, :xl)}
              navigation_enabled={Map.get(@modal_detail_data, :navigation_enabled, true)}
            />
          <% :live_component -> %>
            <.live_component
              module={SelectoComponents.Modal.LiveComponentModal}
              id="detail-modal"
              record={@modal_detail_data.record}
              current_index={@modal_detail_data.current_index}
              total_records={@modal_detail_data.total_records}
              records={@modal_detail_data.records}
              title={Map.get(@modal_detail_data, :title, "Detail Component")}
              title_template={Map.get(@modal_detail_data, :title_template)}
              component_module={Map.get(@modal_detail_data, :component_module)}
              component_assigns={Map.get(@modal_detail_data, :component_assigns, %{})}
              component_assigns_template={Map.get(@modal_detail_data, :component_assigns_template, %{})}
              size={Map.get(@modal_detail_data, :size, :xl)}
              navigation_enabled={Map.get(@modal_detail_data, :navigation_enabled, true)}
            />
          <% _ -> %>
            <.live_component
              module={SelectoComponents.Modal.DetailModal}
              id="detail-modal"
              record={@modal_detail_data.record}
              current_index={@modal_detail_data.current_index}
              total_records={@modal_detail_data.total_records}
              records={@modal_detail_data.records}
              fields={@modal_detail_data.fields}
              related_data={@modal_detail_data.related_data}
              title={Map.get(@modal_detail_data, :title, "Record Details")}
              title_template={Map.get(@modal_detail_data, :title_template)}
              subtitle_field={Map.get(@modal_detail_data, :subtitle_field)}
              size={Map.get(@modal_detail_data, :size, :lg)}
              navigation_enabled={Map.get(@modal_detail_data, :navigation_enabled, true)}
              edit_enabled={Map.get(@modal_detail_data, :edit_enabled, false)}
            />
        <% end %>
      <% end %>
    <% end %>
    """
  end
end
