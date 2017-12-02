defmodule BraidMail.Repo do
  use Ecto.Repo, otp_app: :braidmail

  def init(_, conf) do
    host = Confex.get(:ecto_mnesia, :host)
    conf = [host: host] ++ conf
    {:ok, conf}
  end
end
