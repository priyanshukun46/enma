class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip

    if @query.present?
      q_wildcard = "%#{@query}%"
      @locations = Location.where("name ILIKE :q OR state ILIKE :q OR district ILIKE :q", q: q_wildcard).limit(10)
      @warehouses = Warehouse.where("name ILIKE :q", q: q_wildcard).limit(5)
      @emergencies = Emergency.where("title ILIKE :q OR emergency_type ILIKE :q OR severity ILIKE :q", q: q_wildcard).limit(5)
    else
      @locations = Location.none
      @warehouses = Warehouse.none
      @emergencies = Emergency.none
    end

    @total_results = @locations.size + @warehouses.size + @emergencies.size
  end
end
