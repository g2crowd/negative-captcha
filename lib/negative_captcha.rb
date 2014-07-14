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

    self.message = opts[:message] || <<-MESSAGE
Please try again.
This usually happens because an automated script attempted to submit this form.
    MESSAGE

    self.fields = build_fields opts[:fields]
    self.values = HashWithIndifferentAccess.new
    self.error = "No params provided"

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
      self.error = "Error: Invalid timestamp.  #{message}"
    elsif params[:spinner] != spinner
      self.error = "Error: Invalid spinner.  #{message}"
    elsif invalid_fields_submitted(fields, params)
      self.error = <<-ERROR
Error: Hidden form fields were submitted that should not have been. #{message}
      ERROR

      false
    else
      self.error = ""

      self.values = build_values(fields, params)
    end
  end

  def key_for_field(field_name)
    traverse_query_field_name field_name, fields
  end

  def value_for_field(field_name)
    traverse_query_field_name field_name, values
  end

  def traverse_query_field_name(name, hash)
    path = []

    name.split(/(\[|\]\[|\])/).each_with_index do |i, idx|
      path << i if idx.even?
    end

    traverser = hash
    path.each do |node|
      traverser = traverser[node.to_sym] if traverser.respond_to?(:[])
    end

    traverser
  end

  def recursive_each(*hashes, &block)
    hashes.first.each do |key, value|
      yield *hashes.map { |i| [key, i[key]] }.flatten.concat(hashes)

      if value.respond_to?(:each)
        recursive_each *hashes.map { |i| i[key] || {} }, &block
      end
    end
  end

  def invalid_fields_submitted(fields, params)
    invalid_fields = false

    recursive_each fields, params do |_, _, _, p_val|
      invalid_fields = true if p_val.is_a?(String) && p_val =~ /\S/
    end

    invalid_fields
  end

  def build_values(fields, params, values = HashWithIndifferentAccess.new)
    fields.each do |key, encrypted_key|
      if encrypted_key.respond_to?(:each)
        values[key] = HashWithIndifferentAccess.new
        build_values encrypted_key, (params[key] || {}), values[key]
      else
        values[key] = params[encrypted_key] if params.has_key? encrypted_key
      end
    end

    values
  end

  def build_fields(fields, hash = {})
    fields.each do |item|
      if item.respond_to?(:each)
        item.each do |key, children|
          hash[key] = {}
          build_fields children, hash[key]
        end
      else
        hash[item] = build_field item
      end
    end

    hash
  end

  def build_field(name)
    @@test_mode ?  "test-#{name}" : Digest::MD5.hexdigest([name, spinner, secret].join('-'))
  end
end


require 'negative_captcha/view_helpers'
require 'negative_captcha/form_builder'

class ActionView::Base
  include NegativeCaptchaHelpers
end
