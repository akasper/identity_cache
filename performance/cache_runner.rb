$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require 'active_record'
require 'active_support/core_ext'
require 'active_support/cache'
require 'identity_cache'
require 'memcache'

if ENV['BOXEN_HOME'].present?
  $memcached_port = 21211
  $mysql_port = 13306
else
  $memcached_port = 11211
  $mysql_port = 3306
end

require File.dirname(__FILE__) + '/../test/helpers/active_record_objects'
require File.dirname(__FILE__) + '/../test/helpers/database_connection'
require File.dirname(__FILE__) + '/../test/helpers/cache'

def create_record(id)
  r = Record.new(id)
end

def database_ready(count)
  Record.where(:id => (1..count)).count == count
rescue
  false
end

def create_database(count)
  DatabaseConnection.setup
  a = CacheRunner.new(count)

  a.setup_models

  DatabaseConnection.setup
  # set up associations
  Record.cache_has_one :associated
  Record.cache_has_many :associated_records, :embed => true
  Record.cache_has_many :normalized_associated_records, :embed => false
  Record.cache_index :title, :unique => :true
  AssociatedRecord.cache_has_many :deeply_associated_records, :embed => true

  return if database_ready(count)
  puts "Database not ready for performance testing, generating records"

  DatabaseConnection.drop_tables
  DatabaseConnection.create_tables
  existing = Record.all
  (1..count).to_a.each do |i|
    unless existing.any? { |e| e.id == i }
      a = Record.new
      a.id = i
      a.associated = AssociatedRecord.new(name: "Associated for #{i}")
      a.associated_records
      (1..5).each do |j|
        a.associated_records << AssociatedRecord.new(name: "Has Many #{j} for #{i}")
        a.normalized_associated_records << NormalizedAssociatedRecord.new(name: "Normalized Has Many #{j} for #{i}")
      end
      a.save
    end
  end
end

class CacheRunner
  include ActiveRecordObjects
  include DatabaseConnection

  def initialize(count)
    @count = count
  end

  def prepare
  end
end

class FindRunner < CacheRunner
  def run
    (1..@count).each do |i|
      ::Record.find(i)
    end
  end
end

module MissRunner
  def prepare
    IdentityCache.cache.clear
  end
end

class FetchMissRunner < CacheRunner
  include MissRunner

  def run
    (1..@count).each do |i|
      rec = ::Record.fetch(i)
      rec.fetch_associated
      rec.fetch_associated_records
    end
  end
end

class DoubleFetchMissRunner < CacheRunner
  include MissRunner

  def run
    (1..@count).each do |i|
      rec = ::Record.fetch(i)
      rec.fetch_associated
      rec.fetch_associated_records
      rec.fetch_normalized_associated_records
    end
  end
end

module HitRunner
  def prepare
    IdentityCache.cache.clear
    (1..@count).each do |i|
      rec = ::Record.fetch(i)
      rec.fetch_normalized_associated_records
    end
  end
end

class FetchHitRunner < CacheRunner
  include HitRunner

  def run
    (1..@count).each do |i|
      rec = ::Record.fetch(i)
      # these should all be no cost
      rec.fetch_associated
      rec.fetch_associated_records
    end
  end
end

class DoubleFetchHitRunner < CacheRunner
  include HitRunner

  def run
    (1..@count).each do |i|
      rec = ::Record.fetch(i)
      # these should all be no cost
      rec.fetch_associated
      rec.fetch_associated_records
      rec.fetch_normalized_associated_records
    end
  end
end

