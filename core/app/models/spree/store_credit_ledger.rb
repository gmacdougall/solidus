module Spree
  # StoreCreditLedger provides a series of methods to adjust the balance of
  # a store credit through a trackable accounting system.
  #
  # A change to the balance of the StoreCredit will be added as a
  # StoreCreditLedgerEntry associated with that StoreCredit
  #
  # The balance of a StoreCredit should not be adjusted without going through
  # the ledger, as it will put the balance in an inconsistent state. The amount
  # will be reset when calculated through the ledger in the future.
  class StoreCreditLedger
    # Error to be raised when ledger entry is already settled
    CannotModifySettledLedgerEntryError = Class.new(StandardError)

    # Create a new instance of the store credit ledger
    #
    # @example do
    #   ledger = Spree::StoreCreditLedger.new(store_credit)
    #
    # @api public
    # @param store_credit [Spree::StoreCredit]
    def initialize(store_credit)
      @store_credit = store_credit
    end

    # Mark the specified ledger entry as cleared
    #
    # It will be marked cleared as of the current date and time.
    #
    # Note: If the entry is has already been settled, this method will raise
    # an exception.
    #
    # @example do
    #   ledger.clear(entry)
    #
    # @api public
    # @param entry [Spree::StoreCreditLedgerEntry]
    # @return [void]
    def clear(entry)
      fail(CannotModifySettledLedgerEntryError) if entry.settled?
      entry.update(cleared_at: Time.current)
    end

    # The amount of store credit remaining considering cleared entries only
    #
    # The amount will be returned as a Spree::Money in the currency of the
    # store credit.
    #
    # @example do
    #   ledger.cleared_balance.to_s #=> "$10.00"
    #
    # @api public
    # @return [Spree::Money]
    def cleared_balance
      Spree::Money.new(
        ledger_entries.select(&:cleared?).map(&:amount).inject(:+) || BigDecimal.new(0),
        currency: currency
      )
    end

    # Add the specified amount to ledger
    #
    # The entry will be added in an uncleared, unvoided state.
    #
    # @example
    #   ledger.credit(20, admin_user)
    #
    # @api public
    # @param amount [Numeric] The amount to add to the store credit
    # @param originator [Object] An ActiveRecord model for the object which
    #   initiaed this (for example, an admin user, refund, etc.)
    # @param memo [String] An optional memo to include with the ledger entry
    def credit(amount, originator, memo = nil)
      fail ArgumentError, "Amount must be greater than 0" unless amount > 0
      @store_credit.ledger_entries.create!(
        amount: amount,
        originator: originator,
        memo: memo
      )
    end

    # Remove the specified amount to ledger
    #
    # The entry will be added in an uncleared, unvoided state.
    #
    # @example
    #   ledger.debit(20, 'code-abc', admin_user)
    #
    # @api public
    # @param amount [Numeric] The amount to remove from the store credit
    # @param authorization_code [String] A code for this ledger authorization
    #   which can be associated with a payment or used to void this entry
    #   in the future
    # @param originator [Object] An ActiveRecord model for the object which
    #   initiaed this (for example, an admin user, refund, etc.)
    # @param memo [String] An optional memo to include with the ledger entry
    def debit(amount, authorization_code, originator, memo = nil)
      fail ArgumentError, "Amount must be greater than 0" unless amount > 0
      @store_credit.ledger_entries.create!(
        amount: -amount,
        authorization_code: authorization_code,
        originator: originator,
        memo: memo
      )
    end

    # The amount of store credit authorized but not captured
    #
    # This will note the amount that the balance will change when all
    # currently authorized tranactions are captured.
    #
    # The amount will be returned as a Spree::Money in the currency of the
    # store credit.
    #
    # @example do
    #   ledger.uncleared_balance.to_s #=> "-$20.00"
    #
    # @api public
    # @return [Spree::Money]
    def uncleared_balance
      Spree::Money.new(
        ledger_entries.reject(&:cleared?).map(&:amount).inject(:+) || BigDecimal.new(0),
        currency: currency
      )
    end

    # Mark the specified ledger entry as voided
    #
    # It will be marked voided as of the current date and time.
    #
    # Note: If the entry is has already been settled, this method will raise
    # an exception.
    #
    # @example do
    #   ledger.void(entry)
    #
    # @api public
    # @param entry [Spree::StoreCreditLedgerEntry]
    # @return [void]
    def void(entry)
      fail(CannotModifySettledLedgerEntryError) if entry.settled?
      entry.update(voided_at: Time.current)
    end


    # The amount of store credit available to be spent
    #
    # The amount will be returned as a Spree::Money in the currency of the
    # store credit.
    #
    # @example do
    #   ledger.working_balance.to_s #=> "$10.00"
    #
    # @api public
    # @return [Spree::Money]
    def working_balance
      cleared_balance + uncleared_balance
    end

    private

    def currency
      @store_credit.currency
    end

    def ledger_entries
      @store_credit.ledger_entries.reject(&:voided?)
    end
  end
end
