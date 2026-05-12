defmodule Hooksig.TestCards do
  @moduledoc """
  Static catalog of Stripe test card numbers, grouped by scenario.
  Source: Stripe documentation (testing card section).
  """

  @cards [
    # Success
    %{
      number: "4242 4242 4242 4242",
      brand: "Visa",
      scenario: "success",
      description: "Most common Visa success card. Use any future expiration date, any CVC."
    },
    %{
      number: "4000 0566 5566 5556",
      brand: "Visa (debit)",
      scenario: "success",
      description: "Visa debit, succeeds."
    },
    %{
      number: "5555 5555 5555 4444",
      brand: "Mastercard",
      scenario: "success",
      description: "Mastercard success."
    },
    %{
      number: "5200 8282 8282 8210",
      brand: "Mastercard (debit)",
      scenario: "success",
      description: "Mastercard debit, succeeds."
    },
    %{
      number: "3782 822463 10005",
      brand: "American Express",
      scenario: "success",
      description: "Amex success. CVC is 4 digits."
    },
    %{
      number: "6011 1111 1111 1117",
      brand: "Discover",
      scenario: "success",
      description: "Discover success."
    },
    %{
      number: "3056 9300 0902 0004",
      brand: "Diners Club",
      scenario: "success",
      description: "Diners Club success."
    },
    %{
      number: "3566 0020 2036 0505",
      brand: "JCB",
      scenario: "success",
      description: "JCB success."
    },
    %{
      number: "6200 0000 0000 0005",
      brand: "UnionPay",
      scenario: "success",
      description: "UnionPay success."
    },

    # 3D Secure
    %{
      number: "4000 0025 0000 3155",
      brand: "Visa",
      scenario: "3ds",
      description: "Requires 3D Secure 2 authentication. Always triggers the challenge."
    },
    %{
      number: "4000 0027 6000 3184",
      brand: "Visa",
      scenario: "3ds",
      description: "3DS2 challenge required on every transaction."
    },
    %{
      number: "4000 0084 0000 1629",
      brand: "Visa",
      scenario: "3ds",
      description: "3DS challenge — authentication fails."
    },

    # Declines
    %{
      number: "4000 0000 0000 0002",
      brand: "Visa",
      scenario: "decline",
      description: "Generic decline (`card_declined`)."
    },
    %{
      number: "4000 0000 0000 9995",
      brand: "Visa",
      scenario: "decline",
      description: "Insufficient funds (`insufficient_funds`)."
    },
    %{
      number: "4000 0000 0000 9987",
      brand: "Visa",
      scenario: "decline",
      description: "Lost card decline."
    },
    %{
      number: "4000 0000 0000 9979",
      brand: "Visa",
      scenario: "decline",
      description: "Stolen card decline."
    },
    %{
      number: "4000 0000 0000 0069",
      brand: "Visa",
      scenario: "decline",
      description: "Expired card."
    },
    %{
      number: "4000 0000 0000 0127",
      brand: "Visa",
      scenario: "decline",
      description: "Incorrect CVC."
    },
    %{
      number: "4000 0000 0000 0119",
      brand: "Visa",
      scenario: "decline",
      description: "Processing error."
    },
    %{
      number: "4242 4242 4242 4241",
      brand: "Visa",
      scenario: "decline",
      description: "Invalid card number (fails Luhn check)."
    },

    # Fraud
    %{
      number: "4100 0000 0000 0019",
      brand: "Visa",
      scenario: "fraud",
      description: "Marked as highest risk by Stripe Radar — always blocked."
    },
    %{
      number: "4000 0000 0000 4954",
      brand: "Visa",
      scenario: "fraud",
      description: "Marked as elevated risk."
    },

    # Authentication required (SCA)
    %{
      number: "4000 0027 6000 3184",
      brand: "Visa",
      scenario: "auth",
      description: "Authentication required (`authentication_required`)."
    },
    %{
      number: "4000 0082 6000 3178",
      brand: "Visa",
      scenario: "auth",
      description: "Authentication required, then succeeds."
    },

    # International / regional
    %{
      number: "4000 0000 0000 0077",
      brand: "Visa",
      scenario: "international",
      description: "Charge succeeds, funded but disputed."
    },
    %{
      number: "4000 0035 6000 0008",
      brand: "Visa (BR)",
      scenario: "international",
      description: "Brazilian card — country=BR."
    },
    %{
      number: "4000 0028 0000 0009",
      brand: "Visa (CA)",
      scenario: "international",
      description: "Canadian card — country=CA."
    },
    %{
      number: "4000 0036 6000 0006",
      brand: "Visa (AU)",
      scenario: "international",
      description: "Australian card — country=AU."
    },
    %{
      number: "4000 0082 6000 0000",
      brand: "Visa (FR)",
      scenario: "international",
      description: "French card — country=FR."
    },

    # Disputes
    %{
      number: "4000 0000 0000 0259",
      brand: "Visa",
      scenario: "dispute",
      description: "Charge succeeds, then is disputed as fraudulent."
    },
    %{
      number: "4000 0000 0000 1976",
      brand: "Visa",
      scenario: "dispute",
      description: "Charge succeeds, disputed as `product_not_received`."
    },
    %{
      number: "4000 0000 0000 2685",
      brand: "Visa",
      scenario: "dispute",
      description: "Charge succeeds, disputed but you win."
    }
  ]

  @scenarios [
    {"all", "All scenarios"},
    {"success", "Successful payment"},
    {"3ds", "3D Secure required"},
    {"decline", "Declines"},
    {"fraud", "Fraud / Radar"},
    {"auth", "Authentication required"},
    {"international", "International"},
    {"dispute", "Disputes"}
  ]

  def all, do: @cards
  def scenarios, do: @scenarios

  def filter(query, scenario) do
    query = String.downcase(query)

    @cards
    |> Enum.filter(&matches_scenario?(&1, scenario))
    |> Enum.filter(&matches_query?(&1, query))
  end

  defp matches_scenario?(_, "all"), do: true
  defp matches_scenario?(%{scenario: s}, s), do: true
  defp matches_scenario?(_, _), do: false

  defp matches_query?(_, ""), do: true

  defp matches_query?(card, query) do
    String.contains?(String.downcase(card.number), query) or
      String.contains?(String.downcase(card.brand), query) or
      String.contains?(String.downcase(card.description), query)
  end
end
