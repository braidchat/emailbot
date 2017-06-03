defmodule BraidMail.GmailTest do
  use ExUnit.Case, async: true
  doctest BraidMail.Gmail

  test "Returns user id if HMAC is valid" do
    user_id = UUID.uuid4(:urn)
    assert {:ok, user_id} == (user_id
                              |> BraidMail.Gmail.state_token
                              |> BraidMail.Gmail.verify_state)
  end

  test "Returns :error if HMAC fails" do
    token = BraidMail.Gmail.state_token(UUID.uuid4(:urn))
    [_, nonce, hmac] = String.split token, ";"
    altered_token = Enum.join [UUID.uuid4(:urn), nonce, hmac], ";"
    assert :error == BraidMail.Gmail.verify_state(altered_token)
  end
end
