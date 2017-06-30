# encoding: utf-8

#  Copyright (c) 2008-2017, Puzzle ITC GmbH. This file is part of
#  Cryptopus and licensed under the Affero General Public License version 3 or later.
#  See the COPYING file at the top-level directory or at
#  https://github.com/puzzle/cryptopus.

class SetUidColumnNullableForUsers < ActiveRecord::Migration
  def up
    change_column :users, :uid, :integer, null: true
  end

  def down
    change_column :users, :uid, :integer, null: false
  end
end
