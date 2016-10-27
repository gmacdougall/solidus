module Spree
  # StoreCreditLedgerEntry keeps an accounting history for how a store credit
  # balance has been affected by creation, invalidation, debits, and credits.
  #
  # All modifications to the StoreCredit balance should be reflected in entries
  # in the ledger. As store credits existed before the ledger to track their
  # balance, a migration will run to create an initial balance for all store
  # credits acted on before the ledger was available.
  #
  # The ledger entry has three basic states:
  #
  # - pending (not voided or cleared)
  # - cleared (the entry has been approvied)
  # - voided (the entry was made in error and has been cancelled)
  #
  # Once an entry has been cleared or voided is is considered "settled". A
  # settled entry can no longer be voided or cleared.
  class StoreCreditLedgerEntry < Spree::Base
    belongs_to :store_credit
    belongs_to :originator, polymorphic: true

    delegate :currency, to: :store_credit

    validates_presence_of :amount, :store_credit_id

    extend Spree::DisplayMoney
    money_methods :amount

    # Has this entry been cleared?
    #
    # A cleared entry has been captured by the payment and is considered
    # to be in a finalized state. The entry can no longer be voided or cleared
    # and must be credited back to be undone.
    #
    # @example
    #   entry.cleared? #=> true
    #
    # @api public
    # @return [Boolean] True if the entry has been cleared, false otherwise
    def cleared?
      !!cleared_at
    end

    # Has this entry been settled?
    #
    # A entry is considered settled once it is cleared or voided.
    # Further clear/void actions can no longer be taken on this entry.
    #
    # @example
    #   entry.settled? #=> false
    #
    # @api public
    # @return [Boolean] True if the entry has been voided or cleared, false
    #   otherwise
    def settled?
      cleared? || voided?
    end

    # Has this entry been voided?
    #
    # A voided entry has been cancelled and the entry is considered
    # to be in a finalized state. The entry can no longer be voided or cleared
    # and must be redone.
    #
    # @example
    #   entry.voided? #=> false
    #
    # @api public
    # @return [Boolean] True if the entry has been voided, false otherwise
    def voided?
      !!voided_at
    end
  end
end
