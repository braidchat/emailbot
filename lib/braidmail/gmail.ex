defmodule BraidMail.Gmail do
  @moduledoc """
  Module for interacting with the Gmail api
  """

  @doc """
  Generate a URL to send to the given user which will ask them to authorize us
  """
  def oauth_uri(user_id) do
    "https://accounts.google.com/o/oauth2/auth?" <>
      URI.encode_query %{
        "response_type" => "code",
        "client_id" => Application.fetch_env!(:braidmail, :gmail_id),
        "redirect_uri" => Application.fetch_env!(:braidmail, :gmail_redirect_uri),
        "scope" => "https://www.googleapis.com/auth/gmail.modify",
        "state=" => state_token(user_id),
        "access_type" => "offline",
        "approval_prompt" => "force",
      }
  end

  @doc """
  Generate a state token to be used to securely pass the user id through the
  oauth flow without tampering.
  """
  def state_token(user_id) do
    nonce = Base.encode64(:crypto.strong_rand_bytes(10), padding: false)
    secret = Application.fetch_env!(:braidmail, :gmail_hmac_secret)
    state = Enum.join [user_id, nonce], ";"
    hmac = Base.encode64(:crypto.hmac(:sha256, secret, state), padding: false)
    state <> ";" <> hmac
  end

  @doc """
  Verify the state token after passing through the OAuth flow.
  Returns the `{:ok, user_id}` if the HMAC is valid, `:error` otherwise
  """
  def verify_state(state) do
    [user_id, nonce, hmac] = String.split(state, ";")
    secret = Application.fetch_env!(:braidmail, :gmail_hmac_secret)
    state = Enum.join [user_id, nonce], ";"
    computed_hmac = Base.encode64(:crypto.hmac(:sha256, secret, state),
                                  padding: false)
    if secure_compare(hmac, computed_hmac) do
      {:ok, user_id}
    else
      :error
    end
  end

  @doc """
  Compares two binaries in constant-time to avoid timing attacks.
  """
  def secure_compare(a, b) do
    if byte_size(a) == byte_size(b) do
      secure_compare(a, b, 0) == 0
    else
      false
    end
  end

  defp secure_compare(<<x, a :: binary>>, <<y, b :: binary>>, acc) do
    use Bitwise
    secure_compare(a, b, acc ||| (x ^^^ y))
  end

  defp secure_compare(<<>>, <<>>, acc) do
    acc
  end

end
