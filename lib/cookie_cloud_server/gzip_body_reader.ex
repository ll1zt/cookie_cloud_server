defmodule CookieCloudServer.GzipBodyReader do
  @doc """
  Read the request body and automatically decompress when content-encoding: gzip is found
  """
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        case Plug.Conn.get_req_header(conn, "content-encoding") do
          ["gzip"] ->
            try do
              {:ok, :zlib.gunzip(body), conn}
            rescue
              _ -> {:error, "Invalid gzip data"}
            end

          _ ->
            {:ok, body, conn}
        end

      {:more, _partial_body, _conn} ->
        {:error, "Body too large"}

      other ->
        other
    end
  end
end
