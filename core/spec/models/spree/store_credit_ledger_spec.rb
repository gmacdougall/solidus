require 'spec_helper'

RSpec.describe Spree::StoreCreditLedger, type: :model do
  let(:store_credit) { create :store_credit, amount: 100 }
  let(:ledger) { described_class.new(store_credit) }
  let(:originator) { create :user }
  let(:memo) { 'created by test' }

  RSpec.shared_examples "invalid amount" do
    it 'raises an error' do
      expect { subject }.to raise_error(
        ArgumentError,
        "Amount must be greater than 0"
      )
    end
  end

  describe '#credit' do
    let(:amount) { 10 }

    subject { ledger.credit(amount, originator, memo) }

    it 'creates a new ledger entry' do
      expect { subject }.to change { store_credit.ledger_entries.count }.by(1)
    end

    it 'has the appropriate values on the entry' do
      expect(subject.amount).to eq(10)
      expect(subject.originator).to eq(originator)
      expect(subject.memo).to eq(memo)
    end

    context 'when amount is zero' do
      let(:amount) { 0 }
      it_behaves_like "invalid amount"
    end

    context 'when amount is less than zero' do
      let(:amount) { -1 }
      it_behaves_like "invalid amount"
    end
  end

  describe '#debit' do
    let(:amount) { 10 }

    subject { ledger.debit(amount, 'abc', originator, memo) }

    it 'creates a new ledger entry' do
      expect { subject }.to change { store_credit.ledger_entries.count }.by(1)
    end

    it 'has the appropriate values on the entry' do
      expect(subject.amount).to eq(-10)
      expect(subject.originator).to eq(originator)
      expect(subject.memo).to eq(memo)
    end

    context 'when amount is zero' do
      let(:amount) { 0 }
      it_behaves_like "invalid amount"
    end

    context 'when amount is less than zero' do
      let(:amount) { -1 }
      it_behaves_like "invalid amount"
    end
  end

  describe '#clear' do
    let!(:entry) { ledger.debit(10, 'abc', nil) }

    subject { ledger.clear(entry) }

    context 'when the entry is already settled' do
      before { ledger.void(entry) }

      it 'raises an error' do
        expect { subject }.to raise_error(
          Spree::StoreCreditLedger::CannotModifySettledLedgerEntryError
        )
      end
    end

    context 'when the entry is not settled' do
      it 'marks the entry as cleared' do
        expect { subject }.to change { entry.cleared? }.from(false).to(true)
      end
    end
  end

  describe '#void' do
    let!(:entry) { ledger.debit(10, 'abc', nil) }

    subject { ledger.void(entry) }

    context 'when the entry is already settled' do
      before { ledger.void(entry) }

      it 'raises an error' do
        expect { subject }.to raise_error(
          Spree::StoreCreditLedger::CannotModifySettledLedgerEntryError
        )
      end
    end

    context 'when the entry is not settled' do
      it 'marks the entry as cleared' do
        expect { subject }.to change { entry.voided? }.from(false).to(true)
      end
    end
  end

  describe 'balances' do
    before do
      entry = ledger.debit(5, 'void', nil)
      ledger.void(entry)
      entry = ledger.debit(10, 'clear', nil)
      ledger.clear(entry)
      entry = ledger.debit(20, 'auth', nil)
    end

    describe '#cleared_balance' do
      subject { ledger.cleared_balance }

      it 'returns a spree money' do
        should be_a(Spree::Money)
      end

      it 'contains the amount remaining less cleared transactions' do
        expect(subject.to_d).to eq(90)
      end
    end

    describe '#uncleared_balance' do
      subject { ledger.uncleared_balance }

      it 'returns a spree money' do
        should be_a(Spree::Money)
      end

      it 'contains the sum of all uncleared transactions' do
        expect(subject.to_d).to eq(-20)
      end
    end

    describe '#working_balance' do
      subject { ledger.working_balance }

      it 'returns a spree money' do
        should be_a(Spree::Money)
      end

      it 'contains the amount remaining less all unvoided transactions' do
        expect(subject.to_d).to eq(70)
      end
    end
  end
end
