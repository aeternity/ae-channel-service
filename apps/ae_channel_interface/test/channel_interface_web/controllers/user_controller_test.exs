defmodule AeChannelInterfaceWeb.UserControllerTest do
  use AeChannelInterfaceWeb.ConnCase

  @tag :web
  test "start backend service /new", %{conn: conn} do
    conn = get(conn, "connect/new?initiator_id=ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh&port=1610")

    assert conn.resp_body ==
             "{\"api_endpoint\":\"connect/new\",\"client\":{\"initiator_id\":\"ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh\",\"port\":\"1610\"},\"expected_initiator_configuration\":{\"channel_reserve\":\"2\",\"host\":\"localhost\",\"initiator_amount\":7000000000000,\"initiator_id\":\"ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh\",\"lock_period\":\"10\",\"minimum_depth\":0,\"port\":\"1610\",\"protocol\":\"json-rpc\",\"push_amount\":\"1\",\"responder_amount\":4000000000000,\"responder_id\":\"ak_cFBreUSVWPEc3qSCYHfcy5yW2CWkbdrPkr9itgQfBw1Zdd6HV\",\"role\":\"initiator\"},\"initiator_id\":\"ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh\",\"responder_id\":\"ak_cFBreUSVWPEc3qSCYHfcy5yW2CWkbdrPkr9itgQfBw1Zdd6HV\"}"
  end

  @tag :web
  test "start backend service /new with reestablish", %{conn: conn} do
    conn =
      get(
        conn,
        "connect/new?initiator_id=ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh&port=1610&existing_channel_id=ch_wcNH5tcXDLbpCQpUwzusT4rbzJyF5ukbSKw5TatYe9Y1RwyM4"
      )

    assert conn.resp_body ==
             "{\"api_endpoint\":\"connect/new\",\"client\":{\"existing_channel_id\":\"ch_wcNH5tcXDLbpCQpUwzusT4rbzJyF5ukbSKw5TatYe9Y1RwyM4\",\"initiator_id\":\"ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh\",\"port\":\"1610\"},\"existing_channel_id\":\"ch_wcNH5tcXDLbpCQpUwzusT4rbzJyF5ukbSKw5TatYe9Y1RwyM4\",\"initiator_id\":\"ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh\",\"responder_id\":\"ak_cFBreUSVWPEc3qSCYHfcy5yW2CWkbdrPkr9itgQfBw1Zdd6HV\"}"
  end
end
