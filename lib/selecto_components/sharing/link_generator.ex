defmodule SelectoComponents.Sharing.LinkGenerator do
  @moduledoc """
  Generates shareable links for view configurations with state preservation.
  """

  use Phoenix.Component
  import Phoenix.LiveView

  @doc """
  Component for generating and displaying shareable links.
  """
  def shareable_link(assigns) do
    assigns = assign_defaults(assigns)
    
    ~H"""
    <div class="shareable-link-container">
      <div class="flex items-center space-x-2">
        <input
          type="text"
          value={@link_url}
          readonly
          class="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-sm font-mono"
          id={"shareable-link-#{@id}"}
        />
        
        <button
          type="button"
          phx-click="copy_link"
          phx-value-link={@link_url}
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
          id={"copy-link-#{@id}"}
          phx-hook="CopyToClipboard"
        >
          <.icon name="hero-clipboard-document" class="w-5 h-5" />
          <span class="ml-2">Copy</span>
        </button>
        
        <%= if @show_preview do %>
          <button
            type="button"
            phx-click="preview_link"
            phx-value-link={@link_url}
            class="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700 transition-colors"
          >
            <.icon name="hero-eye" class="w-5 h-5" />
            <span class="ml-2">Preview</span>
          </button>
        <% end %>
        
        <%= if @show_social do %>
          <.social_share_buttons link={@link_url} title={@title} />
        <% end %>
      </div>
      
      <%= if @show_options do %>
        <div class="mt-4 p-4 bg-gray-50 rounded-md">
          <h4 class="font-medium text-sm mb-2">Link Options</h4>
          
          <div class="space-y-2">
            <label class="flex items-center">
              <input
                type="checkbox"
                phx-change="toggle_permission"
                phx-value-permission="read_only"
                checked={@permissions.read_only}
                class="mr-2"
              />
              <span class="text-sm">Read-only access</span>
            </label>
            
            <label class="flex items-center">
              <input
                type="checkbox"
                phx-change="toggle_permission"
                phx-value-permission="allow_export"
                checked={@permissions.allow_export}
                class="mr-2"
              />
              <span class="text-sm">Allow data export</span>
            </label>
            
            <div class="flex items-center space-x-2">
              <label class="text-sm">Expires in:</label>
              <select
                phx-change="update_expiration"
                class="px-2 py-1 border border-gray-300 rounded text-sm"
              >
                <option value="1">1 day</option>
                <option value="7" selected>7 days</option>
                <option value="30">30 days</option>
                <option value="0">Never</option>
              </select>
            </div>
          </div>
        </div>
      <% end %>
      
      <%= if @show_usage do %>
        <div class="mt-4 p-4 bg-blue-50 rounded-md">
          <h4 class="font-medium text-sm mb-2">Link Usage</h4>
          <div class="text-sm text-gray-600">
            <p>Views: <%= @usage_stats.views %></p>
            <p>Last accessed: <%= format_datetime(@usage_stats.last_accessed) %></p>
            <p>Created: <%= format_datetime(@usage_stats.created_at) %></p>
          </div>
        </div>
      <% end %>
    </div>
    
    <%= if @show_qr_modal do %>
      <.qr_code_modal link={@link_url} title={@title} />
    <% end %>
    """
  end

  @doc """
  Social media sharing buttons component.
  """
  def social_share_buttons(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <button
        type="button"
        phx-click="share_social"
        phx-value-platform="twitter"
        phx-value-link={@link}
        phx-value-title={@title}
        class="p-2 bg-blue-400 text-white rounded hover:bg-blue-500 transition-colors"
        title="Share on Twitter"
      >
        <.icon name="hero-share" class="w-4 h-4" />
      </button>
      
      <button
        type="button"
        phx-click="share_social"
        phx-value-platform="linkedin"
        phx-value-link={@link}
        phx-value-title={@title}
        class="p-2 bg-blue-700 text-white rounded hover:bg-blue-800 transition-colors"
        title="Share on LinkedIn"
      >
        <.icon name="hero-share" class="w-4 h-4" />
      </button>
      
      <button
        type="button"
        phx-click="share_social"
        phx-value-platform="email"
        phx-value-link={@link}
        phx-value-title={@title}
        class="p-2 bg-gray-600 text-white rounded hover:bg-gray-700 transition-colors"
        title="Share via Email"
      >
        <.icon name="hero-envelope" class="w-4 h-4" />
      </button>
      
      <button
        type="button"
        phx-click="show_qr_code"
        phx-value-link={@link}
        class="p-2 bg-black text-white rounded hover:bg-gray-800 transition-colors"
        title="Show QR Code"
      >
        <.icon name="hero-qr-code" class="w-4 h-4" />
      </button>
    </div>
    """
  end

  @doc """
  QR code modal component.
  """
  def qr_code_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      phx-click="close_qr_modal"
    >
      <div class="bg-white rounded-lg p-6 max-w-sm" phx-click-away="close_qr_modal">
        <h3 class="text-lg font-semibold mb-4"><%= @title %> - QR Code</h3>
        
        <div class="flex justify-center mb-4">
          <div id="qr-code-display" phx-hook="QRCodeDisplay" data-link={@link}>
            <!-- QR code will be rendered here -->
          </div>
        </div>
        
        <div class="text-center">
          <button
            type="button"
            phx-click="download_qr"
            phx-value-link={@link}
            class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
          >
            Download QR Code
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Generates a shareable link from view configuration.
  """
  def generate_link(view_config, base_url, opts \\ []) do
    state = serialize_view_state(view_config)
    
    # Create shortened URL if needed
    if byte_size(state) > 2000 do
      generate_short_link(state, base_url, opts)
    else
      generate_direct_link(state, base_url, opts)
    end
  end

  @doc """
  Parses a shareable link to restore view state.
  """
  def parse_link(link_or_code) do
    cond do
      String.starts_with?(link_or_code, "http") ->
        parse_direct_link(link_or_code)
      
      String.length(link_or_code) == 8 ->
        parse_short_code(link_or_code)
      
      true ->
        {:error, :invalid_link}
    end
  end

  # Private functions

  defp assign_defaults(assigns) do
    assigns
    |> assign_new(:id, fn -> Ecto.UUID.generate() end)
    |> assign_new(:show_preview, fn -> true end)
    |> assign_new(:show_social, fn -> true end)
    |> assign_new(:show_options, fn -> false end)
    |> assign_new(:show_usage, fn -> false end)
    |> assign_new(:show_qr_modal, fn -> false end)
    |> assign_new(:permissions, fn -> %{read_only: true, allow_export: false} end)
    |> assign_new(:usage_stats, fn -> %{views: 0, last_accessed: nil, created_at: DateTime.utc_now()} end)
    |> assign_new(:title, fn -> "View Configuration" end)
  end

  defp serialize_view_state(view_config) do
    view_config
    |> Map.take([:filters, :sorting, :columns, :grouping, :aggregates])
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  defp generate_short_link(state, base_url, opts) do
    long_url = "#{base_url}/view?state=#{state}"
    
    case SelectoTest.UrlShortener.shorten(long_url, opts) do
      {:ok, shortened} ->
        "#{base_url}/s/#{shortened.short_code}"
      
      {:error, _} ->
        long_url
    end
  end

  defp generate_direct_link(state, base_url, _opts) do
    "#{base_url}/view?state=#{state}"
  end

  defp parse_direct_link(url) do
    uri = URI.parse(url)
    params = URI.decode_query(uri.query || "")
    
    case Map.get(params, "state") do
      nil ->
        {:error, :missing_state}
      
      state ->
        decode_state(state)
    end
  end

  defp parse_short_code(code) do
    case SelectoTest.UrlShortener.resolve(code) do
      {:ok, shortened} ->
        parse_direct_link(shortened.long_url)
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_state(encoded_state) do
    with {:ok, decoded} <- Base.url_decode64(encoded_state, padding: false),
         {:ok, state} <- Jason.decode(decoded) do
      {:ok, state}
    else
      _ -> {:error, :invalid_state}
    end
  end

  defp format_datetime(nil), do: "Never"
  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  defp icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <%= case @name do %>
        <% "hero-clipboard-document" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
        <% "hero-eye" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
        <% "hero-share" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m9.032 4.024a3 3 0 10-2.684-1.342 3 3 0 002.684 1.342zM6.316 10.658a3 3 0 102.684 1.342 3 3 0 00-2.684-1.342z" />
        <% "hero-envelope" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
        <% "hero-qr-code" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h2M4 12h.01M12 12h.01M20 4v.01M20 8v.01M20 16v.01M4 20h.01M4 16h.01M4 8v.01M4 4v.01" />
        <% _ -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
      <% end %>
    </svg>
    """
  end

  @doc """
  JavaScript hooks for clipboard and QR code functionality.
  """
  def __hooks__() do
    """
    export const CopyToClipboard = {
      mounted() {
        this.el.addEventListener("click", (e) => {
          const link = e.currentTarget.getAttribute("phx-value-link");
          navigator.clipboard.writeText(link).then(() => {
            // Change button text temporarily
            const span = this.el.querySelector("span");
            const originalText = span.textContent;
            span.textContent = "Copied!";
            
            setTimeout(() => {
              span.textContent = originalText;
            }, 2000);
          });
        });
      }
    };

    export const QRCodeDisplay = {
      mounted() {
        const link = this.el.dataset.link;
        // In a real implementation, you'd use a QR code library here
        // For now, we'll just show a placeholder
        this.el.innerHTML = `
          <div class="w-48 h-48 bg-gray-200 flex items-center justify-center">
            <span class="text-gray-500">QR Code for: ${link}</span>
          </div>
        `;
      }
    };
    """
  end
end