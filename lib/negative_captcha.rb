require 'digest/md5'
require 'action_view'
require 'active_support/hash_with_indifferent_access'

class NegativeCaptcha
  attr_accessor :fields,
    :values,
    :secret,
    :spinner,
    :message,
    :timestamp,
    :error

  @@test_mode = false
  def self.test_mode=(value)
    class_variable_set(:@@test_mode, value)
  end

  def initialize(opts)
    self.secret = opts[:secret] ||
      Digest::MD5.hexdigest("this_is_a_secret_key")

    if opts.has_key?(:params)
      self.timestamp = opts[:params][:timestamp] || Time.now.to_i
    else
      self.timestamp = Time.now.to_i
    end

    self.spinner = Digest::MD5.hexdigest(
      ([timestamp, secret] + Array(opts[:spinner])).join('-')
    )

    self.message = opts[:message] || t('errors.automated_script_retry')
    self.fields = opts[:fields].inject({}) do |hash, field_name|
      hash[field_name] = @@test_mode ? "test-#{field_name}" : Digest::MD5.hexdigest(
        [field_name, spinner, secret].join('-')
      )

      hash
    end

    self.values = HashWithIndifferentAccess.new
    self.error = t('errors.no_params_provided')

    if opts[:params] && (opts[:params][:spinner] || opts[:params][:timestamp])
      process(opts[:params])
    end
  end

  def [](name)
    fields[name]
  end

  def valid?
    error.blank?
  end

  def process(params)
    timestamp_age = (Time.now.to_i - params[:timestamp].to_i).abs

    if params[:timestamp].nil? || timestamp_age > 86400
      self.error = t('errors.invalid_timestamp', message: message)
    elsif params[:spinner] != spinner
      self.error = t('errors.invalid_spinner', message: message)
    elsif fields.keys.detect {|name| params[name] && params[name] =~ /\S/}
      self.error = t('errors.invalid_fields', message: message)

      false
    else
      self.error = ""

      fields.each do |name, encrypted_name|
        self.values[name] = params[encrypted_name] if params.include? encrypted_name
      end
    end
  end

  private

  def t(key, *rest)
    I18n.t "negative_captcha.#{key}", *rest
  end
end


require 'negative_captcha/view_helpers'
require "negative_captcha/form_builder"
require 'i18n'

I18n.load_path += Dir.glob(File.dirname(__FILE__) + "negative_captcha/locales/*.{yml}")

class ActionView::Base
  include NegativeCaptchaHelpers
end
