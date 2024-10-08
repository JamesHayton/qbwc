class QBWC::Job

  attr_reader :name, :company, :worker_class

  def initialize(name, enabled, company, worker_class, requests = [], data = nil)
    @name = name
    @enabled = enabled
    @company = company || QBWC.company_file_path
    @worker_class = worker_class
    @data = data

    default_key = [nil, company]
    requests = [requests].compact unless Hash === requests || Array === requests
    requests = { default_key => requests } unless Hash === requests || requests.empty?
    @requests = requests

    @request_index = { default_key => 0 }
  end

  def worker
    worker_class.constantize.new
  end

  def process_response(qbxml_response, response, session, advance)
    QBWC.logger.info "Processing response."
    QBWC.logger.info "Job '#{name}' received response: '#{qbxml_response}'." if QBWC.log_requests_and_responses
    
    #find_ar_job
    
    #puts "process response"
    #puts response.class
    #puts response.inspect 
    
    #puts "Getting Job From CouchDB"
    couch_job.requests_completed += 1 #if response["xml_attributes"]["statusCode"] === "0"
    couch_job.save
    #puts the_job.inspect 
    
    #the_job.
    
    
    request_list = requests(session)
    completed_request = request_list[request_index(session)] if request_list
    #advance_next_request(session) if advance
    worker.handle_response(response, session, self, completed_request, data)
  end

  def advance_next_request(session)
    new_index = request_index(session) + 1
    QBWC.logger.info "Job '#{name}' advancing to request #'#{new_index}'."
    @request_index[session.key] = new_index
  end
  
  def couch_job
    @couch_job ||= QBWC::Couch::Job.find_ar_job_with_name(name)
  end

  def enable
    #puts "enable"
    self.enabled = true
  end

  def disable
    #puts "disable"
    self.enabled = false
  end

  def pending?(session)
    #puts "pending?"
    if !enabled?
      QBWC.logger.info "Job '#{name}' not enabled."
      return false
    end
    sr = worker.should_run?(self, session, @data)
    QBWC.logger.info "Job '#{name}' should_run?: #{sr}."
    return sr
  end

  def enabled?
    #puts "enabled?"
    @enabled
  end

  def requests(session)
    begin
    #puts "requests passing session"
    #puts session.inspect 
    secondary_key = session.key.dup
    #puts secondary_key.inspect 
    secondary_key[0] = nil # username = nil
    result = nil
    [session.key, secondary_key].each do |k|
      #puts k.inspect 
      #puts "@requests next"
      #puts @requests.inspect 
      #puts @requests.class 
      #result ||= (@requests || {})[k]
      #result ||= (@requests || {}).values.first  # NEED TO FIX THIS LINE (HACK TO GET A TEST WORKING)
      result ||= (@requests || []) 
      #puts "result next"
      #puts result.inspect 
    end
    #puts "result out of loop next"
    #puts result.inspect
    result
    rescue => e
      #puts e.backtrace
      raise e
    end
  end

  def set_requests(session, requests)
    #puts "set requests"
    @requests ||= []
    @requests   = requests
  end

  def requests=(requests)
    @requests = requests
  end

  def data
    @data
  end

  def data=(d)
    @data = d
  end

  def request_index(session)
    @request_index[session.key] || 0
  end

  def requests_provided_when_job_added
    @requests_provided_when_job_added
  end

  def requests_provided_when_job_added=(value)
    @requests_provided_when_job_added = value
  end

  def next_request(session = QBWC::Session.get)
    
    puts "next request from QBWC::Job class"
    
    reqs = requests(session)

    # Generate and save the requests to run when starting the job.
    if (reqs.nil? || reqs.empty?) && ! self.requests_provided_when_job_added
      greqs = worker.requests(self, session, @data)
      greqs = [greqs] unless greqs.nil? || greqs.is_a?(Array)
      set_requests session, greqs
      reqs = requests(session)
    end

    QBWC.logger.info("Requests available are '#{reqs}'.") if QBWC.log_requests_and_responses
    ri = couch_job.requests_completed #request_index(session)
    QBWC.logger.info("Request index is '#{ri}'.")
    return nil if ri.nil? || reqs.nil? || ri >= reqs.length || couch_job.requests_completed?
    nr = reqs[ri]
    QBWC.logger.info("Next request is '#{nr}'.") if QBWC.log_requests_and_responses
    return QBWC::Request.new(nr) if nr
  end
  alias :next :next_request  # Deprecated method name 'next'

  def reset
    @request_index = {}
    @requests = [] unless self.requests_provided_when_job_added
  end

end
