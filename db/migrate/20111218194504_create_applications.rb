class CreateApplications < ActiveRecord::Migration
  def up
    create_table :applications do |t|
      t.string :sys_name
      t.string :sys_department
    end

    Application.create!(sys_name: 'userManager',      sys_department: 'system')
    Application.create!(sys_name: 'accountManager',   sys_department: 'system')
  end

  def down
    drop_table :applications
  end
end
