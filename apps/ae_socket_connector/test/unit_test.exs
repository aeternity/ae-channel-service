defmodule UnitTest do
  use ExUnit.Case
  require Logger

  @tag :dets_fs
  test "retrive all channels from dets" do
    assert [
             "ch_wcNH5tcXDLbpCQpUwzusT4rbzJyF5ukbSKw5TatYe9Y1RwyM4",
             "ch_2WXxzsKzpxurFTg5WifeRNtSayssq5e1QWrCotdSTvvo2JNoHX",
             "ch_aTjw3Kbd5aZ3ad6DReppXHCtzjWn34VVXzcBsxPusp3qzjjDh"
           ] ==
             SessionHolderHelper.list_channel_ids(
               :responder,
               TestAccounts.responderPubkeyEncoded(),
               "data_test",
               fn channel -> true end
             )
  end

  @tag :dets_fs
  test "retrive only open channels by default" do
    assert [
             "ch_wcNH5tcXDLbpCQpUwzusT4rbzJyF5ukbSKw5TatYe9Y1RwyM4"
           ] ==
             SessionHolderHelper.list_channel_ids(
               :responder,
               TestAccounts.responderPubkeyEncoded(),
               "data_test"
             )
  end

  @tag :dets_fs
  test "retrieve most recent reeestablish data" do
    [channel_id] =
      SessionHolderHelper.list_channel_ids(
        :responder,
        TestAccounts.responderPubkeyEncoded(),
        "data_test"
      )

    channel_info =
      SessionHolderHelper.get_channel_info(
        :responder,
        TestAccounts.responderPubkeyEncoded(),
        channel_id,
        "data_test"
      )

    assert "ch_wcNH5tcXDLbpCQpUwzusT4rbzJyF5ukbSKw5TatYe9Y1RwyM4" ==
             SessionHolder.get_most_recent(channel_info, :channel_id)

    assert "ba_5YODa3x+407NZ3CCLZk1gCxpBFEclyR69J6GnPJJX9BZ6U5s" ==
             SessionHolder.get_most_recent(channel_info, :fsm_id)
  end
end
