class CreateSpreeStoreCreditLedgerEntries < ActiveRecord::Migration[5.0]
  def change
    create_table :spree_store_credit_ledger_entries do |t|
      t.decimal :amount, precision: 8, scale: 2, null: false
      t.references :store_credit, index: true, null: false
      index_name = "idx_spree_sc_ledger_entries_on_orig_type_and_orig_id"
      t.references :originator, polymorphic: true, index: { name: index_name }
      t.string :authorization_code
      t.text :memo
      t.datetime :cleared_at
      t.datetime :voided_at
      t.timestamps null: false
    end

    add_foreign_key :spree_store_credit_ledger_entries, :spree_store_credits, on_delete: :cascade
  end
end
