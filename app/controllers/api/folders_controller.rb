# frozen_string_literal: true

#  Copyright (c) 2008-2017, Puzzle ITC GmbH. This file is part of
#  Cryptopus and licensed under the Affero General Public License version 3 or later.
#  See the COPYING file at the top-level directory or at
#  https://github.com/puzzle/cryptopus.

class Api::FoldersController < ApiController

  self.permitted_attrs = [:name, :description, :team_id]

  def self.policy_class
    FolderPolicy
  end

  # GET /api/folders
  def index
    authorize team, :team_member?
    folders = team.folders
    render_json folders
  end

  # GET /api/folders/:id
  def show
    authorize folder
    super
  end

  # POST /api/teams/:team_id/folders
  def create
    @folder = team.folders.new(model_params)
    authorize folder
    folder.save!
    render_json folder
  end

  # PATCH /api/folders/:id
  def update
    authorize folder
    folder.attributes = model_params

    folder.save!
    render_json folder
  end

  private

  def fetch_entries
    return team.folders if query_param.blank?

    finder(team.folders, query_param).apply
  end

  def finder(folders, query)
    Finders::FoldersFinder.new(folders, query)
  end

  def query_param
    params[:q]
  end

  def folder
    @folder ||= model_class.find(params[:id])
  end

  def entry_url
    '#/folders'
  end

  class << self
    def model_class
      @model_class ||= ::Folder
    end
  end
end
