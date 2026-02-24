defmodule SelectoComponents.Debug.ProductionConfig do
  import Bitwise

  @moduledoc """
  Secure configuration for enabling debug panel in production.

  To enable debug panel in production, you must set BOTH:
  1. SELECTO_DEBUG_ENABLED=true
  2. SELECTO_DEBUG_TOKEN=<secure-random-token>

  And include the token in your session or as a query parameter: ?debug_token=<token>

  This ensures debug panel cannot be accidentally exposed in production.
  """

  @doc """
  Check if debug mode should be enabled based on environment and security requirements.

  Debug is opt-in in all environments and requires a request flag:
  - `selecto_debug=true` (or `1`/`on`/`yes`) in params or session
  - `debug=true` (or `1`/`on`/`yes`) in params or session
  - providing `debug_token` also counts as an explicit request

  In development/test: request flag is sufficient.
  In production: request flag + explicit configuration + valid token.
  """
  def debug_enabled?(params \\ %{}, session \\ %{}) do
    cond do
      # Never show debug UI unless explicitly requested
      !debug_requested?(params, session) ->
        false

      # In dev/test, request flag is enough
      dev_or_test_env?() ->
        true

      # In production, check for explicit enablement and valid token
      production_debug_explicitly_enabled?() ->
        validate_debug_token(params, session)

      # Default: disabled
      true ->
        false
    end
  end

  @doc """
  Get the configured debug features based on environment.
  """
  def get_debug_config(domain_module, _view_type, params \\ %{}, session \\ %{}) do
    if debug_enabled?(params, session) do
      # Use the existing ConfigReader to get debug configuration
      SelectoComponents.Debug.ConfigReader.get_config(domain_module)
    else
      # Return empty config if debug is not enabled
      %{}
    end
  end

  @doc """
  Check if the debug panel CSS should be included.
  This is less strict - we include CSS in dev/test or if debug is configured (but not necessarily authenticated).
  """
  def include_debug_assets?() do
    dev_or_test_env?() || production_debug_explicitly_enabled?()
  end

  # Private functions

  defp dev_or_test_env? do
    # Check various indicators that we're in dev/test
    Application.get_env(:selecto_components, :env) in [:dev, :test] ||
      Application.get_env(:phoenix, :serve_endpoints) == false ||
      System.get_env("MIX_ENV") in ["dev", "test"] ||
      check_mix_env_if_available()
  end

  defp check_mix_env_if_available do
    if Code.ensure_loaded?(Mix) do
      Mix.env() in [:dev, :test]
    else
      false
    end
  end

  defp production_debug_explicitly_enabled? do
    # Require BOTH environment variables to be set
    System.get_env("SELECTO_DEBUG_ENABLED") == "true" &&
      System.get_env("SELECTO_DEBUG_TOKEN") != nil &&
      System.get_env("SELECTO_DEBUG_TOKEN") != ""
  end

  defp validate_debug_token(params, session) do
    configured_token = System.get_env("SELECTO_DEBUG_TOKEN")

    # Check if token is provided and matches
    if configured_token && configured_token != "" do
      provided_token = extract_debug_token(params, session)

      # Use secure comparison to prevent timing attacks
      secure_compare(configured_token, provided_token)
    else
      false
    end
  end

  defp debug_requested?(params, session) do
    flag =
      params["selecto_debug"] ||
        params[:selecto_debug] ||
        params["debug"] ||
        params[:debug] ||
        session["selecto_debug"] ||
        session[:selecto_debug] ||
        session["debug"] ||
        session[:debug]

    truthy_flag?(flag) || token_present?(extract_debug_token(params, session))
  end

  defp extract_debug_token(params, session) do
    params["debug_token"] ||
      params[:debug_token] ||
      session["debug_token"] ||
      session[:debug_token]
  end

  defp token_present?(token) when is_binary(token), do: token != ""
  defp token_present?(_), do: false

  defp truthy_flag?(true), do: true

  defp truthy_flag?(value) when is_binary(value),
    do: String.downcase(value) in ["1", "true", "on", "yes"]

  defp truthy_flag?(_), do: false

  defp secure_compare(nil, _), do: false
  defp secure_compare(_, nil), do: false

  defp secure_compare(a, b) when is_binary(a) and is_binary(b) do
    # Convert to charlist for constant-time comparison
    a_charlist = String.to_charlist(a)
    b_charlist = String.to_charlist(b)

    # Both must be same length
    if length(a_charlist) == length(b_charlist) do
      # XOR each byte and accumulate differences
      # This ensures constant-time comparison
      diff =
        Enum.zip(a_charlist, b_charlist)
        |> Enum.reduce(0, fn {x, y}, acc -> bor(acc, bxor(x, y)) end)

      diff == 0
    else
      false
    end
  end

  defp secure_compare(_, _), do: false

  @doc """
  Generate a secure random token for production debug access.
  Run this in IEx to generate a token for your SELECTO_DEBUG_TOKEN env var.

  ## Example

      iex> SelectoComponents.Debug.ProductionConfig.generate_secure_token()
      "7K9mP3nX5vB2qL8wF4hJ6sD1gR0tY..."
  """
  def generate_secure_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end
end
