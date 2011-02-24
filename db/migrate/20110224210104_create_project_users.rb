class CreateProjectUsers < ActiveRecord::Migration
  def self.up
    create_table :project_users do |t|
      t.integer :project_id
      t.integer :user_id
      t.boolean :allow_editing, :null => false, :default => false

      t.timestamps
    end
  end

  def self.down
    drop_table :project_users
  end
end
