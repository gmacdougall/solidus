require 'spec_helper'

RSpec.describe Spree::StoreCreditLedgerEntry, type: :model do
  let(:amount) { 1 }
  let(:store_credit) { create :store_credit, currency: 'USD' }
  let(:ledger_entry) do
    Spree::StoreCreditLedgerEntry.new(
      amount: amount,
      store_credit: store_credit
    )
  end

  describe 'delegations' do
    it 'delegates currency to store credit' do
      expect(ledger_entry.currency).to eq('USD')
    end
  end

  describe 'validations' do
    subject { ledger_entry }

    context 'when amount is not set' do
      let(:amount) { nil }
      it { should be_invalid }
    end

    context 'when store_credit is not set' do
      let(:store_credit) { nil }
      it { should be_invalid }
    end

    context 'when all required fields are set' do
      it { should be_valid }
    end
  end

  describe '#display_amount' do
    subject { ledger_entry.display_amount }

    it 'returns a Spree::Money' do
      should be_a(Spree::Money)
    end
  end

  describe '#cleared?' do
    subject { ledger_entry.cleared? }

    context 'when cleared_at is null' do
      it { should be false }
    end

    context 'when cleared_at is set' do
      before { ledger_entry.cleared_at = Time.current }

      it { should be true }
    end
  end

  describe '#settled?' do
    subject { ledger_entry.settled? }

    context 'when cleared_at is set' do
      before { ledger_entry.cleared_at = Time.current }

      it { should be true }
    end

    context 'when voided_at is set' do
      before { ledger_entry.voided_at = Time.current }

      it { should be true }
    end

    context 'when cleared_at and voided_at both null ' do
      it { should be false }
    end
  end

  describe '#voided?' do
    subject { ledger_entry.voided? }
    context 'when voided_at is null' do
      it { should be false }
    end

    context 'when voided_at is set' do
      before { ledger_entry.voided_at = Time.current }

      it { should be true }
    end
  end
end
