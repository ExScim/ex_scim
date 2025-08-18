defmodule ExScim.Test.StorageTestHelper do
  def ensure_storage_started do
    case current_storage_adapter() do
      ExScim.Storage.EtsStorage -> ensure_ets_storage_started()
      _ -> :ok
    end
  end

  def stop_storage do
    case current_storage_adapter() do
      ExScim.Storage.EtsStorage -> stop_ets_storage()
      _ -> :ok
    end
  end

  def current_storage_adapter do
    Application.get_env(:ex_scim, :storage_strategy, ExScim.Storage.EtsStorage)
  end

  def ensure_ets_storage_started do
    case GenServer.whereis(ExScim.Storage.EtsStorage) do
      nil ->
        case ExScim.Storage.EtsStorage.start_link() do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          error -> error
        end
      _pid ->
        :ok
    end
  end

  def stop_ets_storage do
    case GenServer.whereis(ExScim.Storage.EtsStorage) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal)
    end
  end

  def clear_storage do
    case current_storage_adapter() do
      ExScim.Storage.EtsStorage ->
        case GenServer.whereis(ExScim.Storage.EtsStorage) do
          nil -> :ok
          _pid -> ExScim.Storage.EtsStorage.clear_all()
        end
      _ ->
        :ok
    end
  end
end