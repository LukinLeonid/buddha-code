Sequel.migration do
  up do
    create_table(:news) do
      String :id, primary_key: true
      Date :date, null: false
      String :title, null: false
      String :cut
      String :body, null: false
      String :ext, null: false
      Boolean :is_dir, null: false
      String :buddha_node
      DateTime :last_modified, null: false
    end
  end

  down do
    drop_table(:news)
  end
end
