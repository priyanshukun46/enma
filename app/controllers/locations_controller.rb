class LocationsController < ApplicationController
  def index
    @locations = Location.all.order(:name)
  end
end
