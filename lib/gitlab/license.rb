require "openssl"
require "date"
require "json"
require "base64"

require "gitlab/license/version"
require "gitlab/license/encryptor"
require "gitlab/license/boundary"

module Gitlab
  class License
    class Error < StandardError; end
    class ImportError < Error; end
    class ValidationError < Error; end

    class << self
      attr_reader :encryption_key
      @encryption_key = nil

      def encryption_key=(key)
        if key && !key.is_a?(OpenSSL::PKey::RSA)
          raise ArgumentError, "No RSA encryption key provided."
        end

        @encryption_key = key
        @encryptor = nil
      end

      def encryptor
        @encryptor ||= Encryptor.new(self.encryption_key)
      end

      def import(data)
        if data.nil?
          raise ImportError, "No license data."
        end

        data = Boundary.remove_boundary(data)

        begin
          license_json = encryptor.decrypt(data)
        rescue Encryptor::Error
          raise ImportError, "License data could not be decrypted."
        end

        begin
          attributes = JSON.parse(license_json)
        rescue JSON::ParseError
          raise ImportError, "License data is invalid JSON."
        end

        new(attributes)
      end
    end

    attr_reader :version
    attr_accessor :licensee, :starts_at, :expires_at
    attr_accessor :notify_admins_at, :notify_users_at, :block_changes_at
    attr_accessor :restrictions

    alias_method :issued_at, :starts_at
    alias_method :issued_at=, :starts_at=

    def initialize(attributes = {})
      load_attributes(attributes)
    end

    def valid?
      return false if !licensee         || !licensee.is_a?(Hash) || licensee.length == 0
      return false if !starts_at        || !starts_at.is_a?(Date)
      return false if expires_at        && !expires_at.is_a?(Date)
      return false if notify_admins_at  && !notify_admins_at.is_a?(Date)
      return false if notify_users_at   && !notify_users_at.is_a?(Date)
      return false if block_changes_at  && !block_changes_at.is_a?(Date)
      return false if restrictions      && !restrictions.is_a?(Hash)

      true
    end

    def validate!
      raise ValidationError, "License is invalid" unless valid?
    end

    def will_expire?
      self.expires_at
    end

    def will_notify_admins?
      self.notify_admins_at
    end

    def will_notify_users?
      self.notify_users_at
    end

    def will_block_changes?
      self.block_changes_at
    end

    def expired?
      will_expire? && Date.today >= self.expires_at
    end

    def notify_admins?
      will_notify_admins? && Date.today >= self.notify_admins_at
    end

    def notify_users?
      will_notify_users? && Date.today >= self.notify_users_at
    end

    def block_changes?
      will_block_changes? && Date.today >= self.block_changes_at
    end

    def restricted?(key = nil)
      if key
        restricted? && restrictions.has_key?(key)
      else
        restrictions && restrictions.length >= 1
      end
    end

    def attributes
      hash = {}

      hash["version"]          = self.version
      hash["licensee"]         = self.licensee

      # `issued_at` is the legacy name for starts_at.
      # TODO: Move to starts_at in a next version.
      hash["issued_at"]        = self.starts_at
      hash["expires_at"]       = self.expires_at       if self.will_expire?

      hash["notify_admins_at"] = self.notify_admins_at if self.will_notify_admins?
      hash["notify_users_at"]  = self.notify_users_at  if self.will_notify_users?
      hash["block_changes_at"] = self.block_changes_at if self.will_block_changes?

      hash["restrictions"]     = self.restrictions     if self.restricted?

      hash
    end

    def to_json
      JSON.dump(self.attributes)
    end

    def export(boundary: nil)
      validate!

      data = self.class.encryptor.encrypt(self.to_json)

      if boundary
        data = Boundary.add_boundary(data, boundary)
      end

      data
    end

    private

    def load_attributes(attributes)
      attributes = Hash[attributes.map { |k, v| [k.to_s, v] }]

      version = attributes["version"] || 1
      unless version && version == 1
        raise ArgumentError, "Version is too new"
      end

      @version = version

      @licensee = attributes["licensee"]

      # `issued_at` is the legacy name for starts_at.
      # TODO: Move to starts_at in a next version.
      %w(issued_at expires_at notify_admins_at notify_users_at block_changes_at).each do |attr|
        value = attributes[attr]
        value = Date.parse(value) rescue nil if value.is_a?(String)

        next unless value

        send("#{attr}=", value)
      end

      restrictions = attributes["restrictions"]
      if restrictions && restrictions.is_a?(Hash)
        restrictions = Hash[restrictions.map { |k, v| [k.to_sym, v] }]
        @restrictions = restrictions
      end
    end
  end
end
