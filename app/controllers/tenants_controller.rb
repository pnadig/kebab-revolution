# Kebab 2.0 - Server Ror
#
# Author::    Onur Özgür ÖZKAN <onur.ozgur.ozkan@lab2023.com>
# Copyright:: Copyright (c) 2011 lab2023 - internet technologies
# License::   Distributes under MIT

# Tenants Controller
class TenantsController < ApplicationController
  skip_around_filter  :tenant,        only: [:create, :valid_host]
  skip_before_filter  :authorize,     only: [:create, :valid_host]
  skip_before_filter  :authenticate

  # POST/tenants
  def create

    Tenant.transaction do

      @plan = Plan.find(params[:plan][:id])
      @tenant = Tenant.new(params[:tenant])

      if @tenant.save

        Tenant.current = @tenant
        Time.zone = params[:user][:time_zone]
        I18n.locale = params[:user][:locale]

        @user = User.new(params[:user])
        admin = Role.create(name: 'Admin')
        admin.privileges << Privilege.all
        admin.save

        @user.tenant = @tenant
        @user.roles << admin
        @user.save

        if @user.save

          # KBBTODO Refactor this ugly code
          @subscription                   = Subscription.new
          @subscription.user              = @user
          @subscription.tenant            = @tenant
          @subscription.plan              = @plan
          @subscription.price             = @plan.price
          @subscription.user_limit        = @plan.user_limit
          @subscription.payment_period    = 0
          @subscription.next_payment_date = Time.zone.now + 1.months

          if @subscription.save
            # KBBTODO #75 use delay job for sending mail in future
            TenantMailer.create_tenant(@user, @tenant, @subscription).deliver
            login @user, params[:user][:password]
            status = :created
          else
            @tenant.delete
            @user.delete
            @subscription.valid?
            @subscription.errors.each { |a, m| add_error a, m}
            status = :unprocessable_entity
          end

        else
          @tenant.delete
          @user.delete
          @user.errors.each { |a, m| add_error a, m}
          status = :unprocessable_entity
        end
      else
        @tenant.errors.each { |a, m| add_error a, m}
        status = :unprocessable_entity
      end
    end
    render json: @@response, status: status
  end

  # GET/tenant/1
  def show
    @@response[:data]         = Hash.new
    @@response[:data][:next]  = @current_tenant.subscription
    @@response[:data][:older] = @current_tenant.subscription.payments

    render json: @@response
  end

  # DELETE/tenants/:id
  # KBBTODO move all delete code to tenants#delete private method
  def destroy
    if is_owner session[:user_id]
      if @current_tenant.subscription.paypal_recurring_payment_profile_token
        ppr = PayPal::Recurring.new(:profile_id => @current_tenant.subscription.paypal_recurring_payment_profile_token)
        ppr.cancel
      end
      @current_tenant.passive_at = Time.zone.now
      @current_tenant.save
      logout
      render json: @@response
    else
      add_notice 'ERR', 'only owner can delete the account'
      render json: {success: false}
    end
  end

  # GET/tenants/valid_host?host=host_name
  # KBBTODO #64 set invalid tenant from one place
  def valid_host
    if Tenant.find_by_host(params[:host]) != nil \
       || %w(www help support api apps status blog lab2023 static).include?(params[:host].split('.').first) \
       || params[:host].split('.').count != 3
      render json: {success: false}
    else
      render json: @@response
    end
  end
end
