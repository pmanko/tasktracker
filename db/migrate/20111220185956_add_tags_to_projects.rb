class AddTagsToProjects < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :tags, :text
  end
end
