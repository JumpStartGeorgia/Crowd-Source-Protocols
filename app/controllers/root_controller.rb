class RootController < ApplicationController
  require 'utf8_converter'
  
  before_filter :authenticate_user!, :except => [:index, :download, :generate_spreadsheet]

  def index
    @overall_stats = DistrictPrecinct.overall_stats
    @overall_stats_by_district = DistrictPrecinct.overall_stats_by_district
    @overall_user_stats = CrowdDatum.overall_user_stats

    respond_to do |format|
      format.html # index.html.erb
    end
  end

  def protocol

    # if the user has not completed training send them there
    trained = current_user.trained.present? ? current_user.trained.split(',') : []
    if trained.length < 5
      redirect_to training_path, :notice => I18n.t('root.protocol.no_training')
      return
    end

    valid = true
    if request.post?
      @crowd_datum = CrowdDatum.new(params[:crowd_datum])
      valid = @crowd_datum.save
  		@user_stats = CrowdDatum.overall_stats_by_user(current_user.id) 
    end

    # get the next record if there were no errors
    @crowd_datum = CrowdDatum.next_available_record(current_user.id) if valid
    
    respond_to do |format|
      format.html # index.html.erb
    end
  end

  def training
    protocols = (1..5).to_a

    user = User.find(current_user.id)
    trained = user.trained.present? ? user.trained.split(',') : []
    trained = trained.map{|x| x.to_i}

    if params['protocol'].present?
      @next_protocol = params['protocol_number']
      filedata = JSON.parse(File.read('public/training/' + @next_protocol + '.json'))
      if filedata == params['protocol']
        trained = (trained + [@next_protocol.to_i]).uniq.sort
        user.trained = trained.join(',')
        user.save
  			flash[:notice] = I18n.t('root.training.success')
      else
        @errors = []
        filedata.each_pair do |key, value|
          if value != params['protocol'][key]
            @errors.push(key)
          end
        end
  			flash[:alert] = I18n.t('root.training.data_mismatch')
      end
    end

    # if no errors, load the next protocol
    if @errors.blank?
      params['protocol'] = nil # make sure form fields are not pre-populated with the last form
      if user.trained.blank?
        @next_protocol = protocols.sample
      else
        left = protocols - trained
        if left.present?
          @next_protocol = left.sample
        else
          redirect_to protocol_path, :notice => I18n.t('root.training.completed')
          return
        end
      end
    end

    respond_to do |format|
      format.html # index.html.erb
    end
  end
  
  def download
    @num_precincts = President2013.count
    @total_precincts = DistrictPrecinct.count
  
    respond_to do |format|
      format.html # index.html.erb
    end
  end
  
  def generate_spreadsheet

		# create file name using event name and map title that were passed in
    filename = I18n.t('app.common.file_name')
		filename << "-#{l Time.now, :format => :file}"

		respond_to do |format|
		  format.csv {
logger.debug ">>>>>>>>>>>>>>>> format = csv"
        send_data President2013.download_precinct_data, 
		      :type => 'text/csv; header=present',
		      :disposition => "attachment; filename=#{clean_filename(filename)}.csv"
			}

		  format.xls{
logger.debug ">>>>>>>>>>>>>>>> format = xls"
				send_data President2013.download_precinct_data, 
		    :disposition => "attachment; filename=#{clean_filename(filename)}.xls"
			}
		end
  
  end


  def election_data_spreadsheet

		# create file name using event name and map title that were passed in
    filename = I18n.t('app.common.file_name')
		filename << "-#{l Time.now, :format => :file}"

		respond_to do |format|
		  format.csv {
logger.debug ">>>>>>>>>>>>>>>> format = csv"
        send_data President2013.download_election_map_data, 
		      :type => 'text/csv; header=present',
		      :disposition => "attachment; filename=#{clean_filename(filename)}.csv"
			}
		end
  end



  protected
  
	# remove bad characters from file name
	def clean_filename(filename)
		Utf8Converter.convert_ka_to_en(filename.gsub(' ', '_').gsub(/[\\ \/ \: \* \? \" \< \> \| \, \. ]/,''))
	end
  
end
