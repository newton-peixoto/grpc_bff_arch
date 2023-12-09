defmodule Repository.UserRepository do
  require Logger
  use GenServer

  # Client

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{id: 1, users: %{}}, name: __MODULE__)
  end

  def save(user = %{name: _name, email: _email}) do
    GenServer.call(__MODULE__, {:save, user})
  end

  def delete(id) do
    GenServer.cast(__MODULE__, {:delete, id})
  end

  def get_all() do
    GenServer.call(__MODULE__, :get_all)
  end

  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  # Server (callbacks)

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:delete, id}, state = %{users: users}) do
    users = Map.delete(users, id)

    {:noreply, %{state | users: users}}
  end

  @impl true
  def handle_call({:save, user}, _from, state = %{id: id, users: users}) do
    user = Map.put(user, :id, id)
    users = Map.put(users, id, user )
    Logger.info("Saving data into database")
    {:reply, user, %{state | users: users, id: id + 1}}
  end

  @impl true
  def handle_call(:get_all, _from, state = %{users: users}) do

    {:reply, Map.to_list(users), state}
  end

  @impl true
  def handle_call({:get, id}, _from, state = %{users: users}) do
    Logger.info("Retrieving data from database")
    {:reply, Map.get(users, id), state}
  end
end
