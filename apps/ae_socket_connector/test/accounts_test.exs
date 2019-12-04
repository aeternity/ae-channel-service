defmodule TestAccounts do
  # def responderPubkeyEncoded() do
  #   "ak_26xYuZJnxpjuBqkvXQ4EKb4Ludt8w3rGWREvEwm68qdtJLyLwq"
  # end

  # def responderPrivkey() do
  #   <<55, 112, 8, 133, 136, 186, 103, 209, 225, 173, 157, 98, 179, 248, 227, 75, 64, 253, 175, 97, 81, 149, 27,
  #     108, 35, 160, 80, 16, 121, 176, 159, 138, 145, 57, 82, 197, 159, 203, 87, 93, 38, 245, 163, 158, 237, 249,
  #     101, 141, 158, 185, 198, 87, 190, 11, 15, 96, 80, 225, 138, 111, 252, 37, 59, 78>>
  # end

  # def initiatorPubkeyEncoded do
  #   "ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS"
  # end

  # def initiatorPrivkey() do
  #   <<133, 143, 10, 3, 177, 135, 2, 205, 204, 153, 181, 19, 83, 137, 93, 186, 100, 92, 12, 201, 228, 174, 194, 70,
  #     27, 220, 3, 227, 212, 32, 203, 247, 106, 164, 29, 213, 77, 73, 184, 77, 59, 65, 33, 156, 241, 78, 239, 173,
  #     39, 2, 126, 254, 111, 28, 73, 150, 6, 150, 66, 20, 47, 81, 213, 153>>
  # end

  # add you accounts below if created with cli remeber to keep 0x

  def responderPubkeyEncoded() do
    "ak_cFBreUSVWPEc3qSCYHfcy5yW2CWkbdrPkr9itgQfBw1Zdd6HV"
  end

  def responderPrivkey() do
    :binary.encode_unsigned(
      0x6E0E0B82311DB4C085AD3E4B8A9C70B840393B30D3C8747872AA6D93541E5B4C5006F5F3D29954144D028FDF781CFAFBDBFFB6E8FEBFCF0AFF729BF28A92C98E
    )
  end

  def initiatorPubkeyEncoded do
    "ak_2DDLbYBhHcuAzNg5Un853NRbUr8JVjZeMc6mTUpwmiVzA4ic6X"
    # "ak_SVQ9RvinB2E8pio2kxtZqhRDwHEsmDAdQCQUhQHki5QyPxtMh"
  end

  def initiatorPrivkey() do
    :binary.encode_unsigned(
      0x5245D200D51B048C825280578EDDA2160F48859D49DCFC3510D87CC46758C97C39E09993C3D5B1147F002925270F7E7E112425ABA0137A6E8A929846A3DFD871
    )
  end
end
