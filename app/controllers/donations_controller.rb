class DonationsController < ApplicationController
  require 'json'
  require 'net/http'
  require 'uri'

  before_action :set_donation, only: %i[ show edit update destroy ]

  # GET /donations or /donations.json
  def index
    @donations = Donation.all
  end

  # GET /donations/1 or /donations/1.json
  def show
    @qrcode = RQRCode::QRCode.new(@donation.payment_url)

    @svg = @qrcode.as_svg(
      offset: 0,
      color: '000',
      shape_rendering: 'crispEdges',
      module_size: 6

    )
  end

  def check_donation
    
  end
  

  # GET /donations/new
  def new
    @donation = Donation.new
  end

  # GET /donations/1/edit
  def edit
  end

  # POST /donations or /donations.json
  def create
    @donation = Donation.new(donation_params)
    @donation.status = "pending"
#define payload for mach
    payload = JSON.dump({
      payment:{
        amount: @donation.amount,
        message: @donation.message,
        title: @donation.title
      }
    })
#url for mach
    url = URI("https://biz-sandbox.soymach.com/payments")
#create http object
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    #create request for mach
    request = NET::HTTP::Post.new(url)
    request["Content-Type"] = 'application/json'
    request["Authorization"] = ENV["mach_key_sandbox"]
    #set body 
    request.body = payload
    response = http.request(request)
    #parse response
    response_body = JSON.parse(response.body.force_encoding("UTF-8"))
    @donation.code = response_body["token"]
    @donation.payment_url = response_body["url"]
    respond_to do |format|
      if @donation.save!
        format.html {redirect_to @donation, notice: " donation was succesfully accept"}
      end
    end
  end

  # PATCH/PUT /donations/1 or /donations/1.json
  def update
    respond_to do |format|
      if @donation.update(donation_params)
        format.html { redirect_to @donation, notice: "Donation was successfully updated." }
        format.json { render :show, status: :ok, location: @donation }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @donation.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /donations/1 or /donations/1.json
  def destroy
    @donation.destroy
    respond_to do |format|
      format.html { redirect_to donations_url, notice: "Donation was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def webhook
    donation = Donation.find_by(code: params["event_resources_id"])
    case params["event_name"] = "business-payment-completed"
    when true
      donation.status = "paid"
      donation.save!
      render json: {
        success: true,
        message: "Donation was successfully"
      }, status:200
    else
      donation.status = "failed"
      donation.save!
      render json: {
        success: true,
        message: "Donation not successfully"
      }, status:200
    end
  end
  

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_donation
      @donation = Donation.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def donation_params
      params.require(:donation).permit(:amount, :title, :message)
    end
end
