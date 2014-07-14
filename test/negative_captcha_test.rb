require "action_view"
require 'test/unit'
require_relative '../lib/negative_captcha'

class NegativeCaptchaTest < Test::Unit::TestCase

  def test_view_helpers
    assert ActionView::Base.instance_methods.include?(:negative_captcha)
  end

  def encrypted_params(captcha, fields = nil)
    build_params(fields || captcha.fields)
  end

  def build_params(fields, params = {})
    fields.each do |key, item|
      if item.respond_to?(:each)
        params[key] = {}
        build_params item, params[key]
      else
        params[item] = key.to_s
      end
    end

    params
  end

  def test_valid_submission
    fields = [:name, :comment]
    captcha = NegativeCaptcha.new(:fields => fields)
    assert captcha.fields.is_a?(Hash)
    assert_equal captcha.fields.keys.sort{|a,b|a.to_s<=>b.to_s}, fields.sort{|a,b|a.to_s<=>b.to_s}

    filled_form = NegativeCaptcha.new(
      :fields => fields,
      :timestamp => captcha.timestamp,
      :params => {:timestamp => captcha.timestamp, :spinner => captcha.spinner}.merge(encrypted_params(captcha))
    )
    assert_equal "", filled_form.error
    assert filled_form.valid?
    assert_equal 'name', filled_form.values[:name]
    assert_equal 'comment', filled_form.values[:comment]

    assert_equal 'name', filled_form.values['name']
    assert_equal 'comment', filled_form.values['comment']
  end

  def test_values_can_include_nested
    fields = [:one, children: [:two, children: [:three]]]
    captcha = NegativeCaptcha.new(:fields => fields)
    assert captcha.fields.is_a?(Hash)
    assert captcha.fields.has_key?(:one), 'Has root key'
    assert captcha.fields.has_key?(:children), 'has children'
    assert captcha.fields[:children].has_key?(:two), 'has two'
    assert captcha.fields[:children][:children].has_key?(:three), 'has three'
  end

  def test_valid_nested_submission
    fields = [:one, nest: [:two, nest: [:three]]]
    captcha = NegativeCaptcha.new(:fields => fields)

    filled_form = NegativeCaptcha.new(
      :fields => fields,
      :timestamp => captcha.timestamp,
      :params => { :timestamp => captcha.timestamp,
                   :spinner => captcha.spinner }.merge(encrypted_params(captcha))
    )

    assert_equal '', filled_form.error
    assert_equal 'one', filled_form.values[:one]
    assert_equal 'two', filled_form.values[:nest][:two]
  end

  def test_missing_fields_are_not_in_values
    fields = [:name, :comment, :widget]
    captcha = NegativeCaptcha.new(:fields => fields)
    assert captcha.fields.is_a?(Hash)
    assert_equal captcha.fields.keys.sort{|a,b|a.to_s<=>b.to_s}, fields.sort{|a,b|a.to_s<=>b.to_s}

    params = encrypted_params(captcha)
    params = Hash[params.reject { |key, value| value == 'widget' }]

    filled_form = NegativeCaptcha.new(
      :fields => fields,
      :timestamp => captcha.timestamp,
      :params => {:timestamp => captcha.timestamp, :spinner => captcha.spinner}.merge(params)
    )
    assert_equal "", filled_form.error
    assert filled_form.valid?

    assert_equal({'name' => 'name', 'comment' => 'comment'}, filled_form.values)
  end

  def test_missing_timestamp
    fields = [:name, :comment]
    captcha = NegativeCaptcha.new(:fields => fields)
    assert captcha.fields.is_a?(Hash)
    assert_equal captcha.fields.keys.sort{|a,b|a.to_s<=>b.to_s}, fields.sort{|a,b|a.to_s<=>b.to_s}

    filled_form = NegativeCaptcha.new(
      :fields => fields,
      :timestamp => captcha.timestamp,
      :params => {:spinner => captcha.spinner}.merge(encrypted_params(captcha))
    )
    assert !filled_form.valid?
    assert filled_form.error.match(/timestamp/).is_a?(MatchData)
  end

  def test_bad_timestamp
    fields = [:name, :comment]
    captcha = NegativeCaptcha.new(:fields => fields)
    assert captcha.fields.is_a?(Hash)
    assert_equal captcha.fields.keys.sort{|a,b|a.to_s<=>b.to_s}, fields.sort{|a,b|a.to_s<=>b.to_s}

    filled_form = NegativeCaptcha.new(
      :fields => fields,
      :timestamp => captcha.timestamp,
      :params => {:timestamp => 1209600, :spinner => captcha.spinner}.merge(encrypted_params(captcha))
    )
    assert !filled_form.valid?
    assert filled_form.error.match(/timestamp/).is_a?(MatchData)
  end

  def test_missing_spinner
    fields = [:name, :comment]
    captcha = NegativeCaptcha.new(:fields => fields)
    assert captcha.fields.is_a?(Hash)
    assert_equal captcha.fields.keys.sort{|a,b|a.to_s<=>b.to_s}, fields.sort{|a,b|a.to_s<=>b.to_s}

    filled_form = NegativeCaptcha.new(
      :fields => fields,
      :timestamp => captcha.timestamp,
      :params => {:timestamp => captcha.timestamp}.merge(encrypted_params(captcha))
    )
    assert !filled_form.valid?
    assert filled_form.error.match(/spinner/).is_a?(MatchData)
  end

  def test_bad_spinner
    fields = [:name, :comment]
    captcha = NegativeCaptcha.new(:fields => fields)
    assert captcha.fields.is_a?(Hash)
    assert_equal captcha.fields.keys.sort{|a,b|a.to_s<=>b.to_s}, fields.sort{|a,b|a.to_s<=>b.to_s}

    filled_form = NegativeCaptcha.new(
      :fields => fields,
      :timestamp => captcha.timestamp,
      :params => {:timestamp => captcha.timestamp, :spinner => captcha.spinner.reverse}.merge(encrypted_params(captcha))
    )
    assert !filled_form.valid?
    assert filled_form.error.match(/spinner/).is_a?(MatchData)
  end

  def test_includes_honeypots
    fields = [:name, :comment]
    captcha = NegativeCaptcha.new(:fields => fields)
    assert captcha.fields.is_a?(Hash)
    assert_equal captcha.fields.keys.sort{|a,b|a.to_s<=>b.to_s}, fields.sort{|a,b|a.to_s<=>b.to_s}

    filled_form = NegativeCaptcha.new(
      :fields => fields,
      :timestamp => captcha.timestamp,
      :params => {:timestamp => captcha.timestamp, :spinner => captcha.spinner, :name => "Test"}.merge(encrypted_params(captcha))
    )
    assert !filled_form.valid?
    assert filled_form.error.match(/hidden/i).is_a?(MatchData)
  end

  def test_valid_submission_with_only_whitespaces_in_fields
    fields = [:one, :two, :three]
    captcha = NegativeCaptcha.new(:fields => fields)

    filled_form = NegativeCaptcha.new(
      :fields => fields,
      :timestamp => captcha.timestamp,
      :params => {:timestamp => captcha.timestamp, :spinner => captcha.spinner, :one => ' ', :two => "\r\n", :three => "\n"}.merge(encrypted_params(captcha))
    )
    assert_equal "", filled_form.error
    assert filled_form.valid?
  end

  def test_key_for_field
    fields = [:one, :nest => [:two, :nest => [:three]]]
    captcha = NegativeCaptcha.new fields: fields

    assert captcha.key_for_field('one').is_a?(String), 'has one'
    assert captcha.key_for_field('two').nil?, 'no two'
    assert_equal true, captcha.key_for_field('nest[two]').is_a?(String)
    assert_equal true, captcha.key_for_field('nest[nest][three]').is_a?(String)
  end

  def test_recursive_each
    hash1 = {
      a: 1,
      b: { c: 2, d: 3 },
      c: { e: 4, f: 5 },
      d: { g: 1 }
    }

    hash2 = {
      a: 10,
      b: { c: 20, d: 30 },
      c: { e: 40 }
    }

    flattened = []
    NegativeCaptcha.new(fields: {}).recursive_each hash1, hash2 do |_, value1, _, value2|
      flattened << [value1, value2] unless value1.is_a?(Hash)
    end

    assert_equal flattened, [
      [1, 10], [2, 20], [3, 30], [4, 40], [5, nil], [1, nil]
    ]
  end
end
