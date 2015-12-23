# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/properties'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Tingyun Agent support.
    class TingyunAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER)['credentials']
        java_opts   = @droplet.java_opts
        configuration = {}

        apply_configuration(credentials, configuration)
        apply_user_configuration(credentials, configuration)
        write_properties_configuration(credentials)
        write_java_opts(java_opts, configuration)

        java_opts.add_javaagent(@droplet.sandbox + jar_name)
                 .add_system_property('tingyun.home', @droplet.sandbox)
        java_opts.add_system_property('tingyun.enable.java.8', 'true') if @droplet.java_home.java_8_or_later?
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, [LICENSE_KEY, LICENSE_KEY_USER]
      end

      private

      FILTER = /tingyun/.freeze

      LICENSE_KEY = 'licenseKey'.freeze

      LICENSE_KEY_USER = 'license_key'.freeze

      private_constant :FILTER, :LICENSE_KEY, :LICENSE_KEY_USER

      def apply_configuration(credentials, configuration)
        configuration['agent_log_file_name'] = 'STDOUT'
        configuration[LICENSE_KEY_USER] = credentials[LICENSE_KEY]
        configuration['app_name'] = @application.details['application_name']
      end

      def write_properties_configuration(credentials)
        tingyunProps = @droplet.sandbox + "tingyun.properties"
         agent_log_file_count = JavaBuildpack::Util::Properties.new(tingyunProps)['nbs.agent_log_file_count']
         agent_log_file_size = JavaBuildpack::Util::Properties.new(tingyunProps)['nbs.agent_log_file_size']
         agent_log_level = JavaBuildpack::Util::Properties.new(tingyunProps)['nbs.agent_log_level']
         props_hash = {
         "nbs.license_key" => credentials[LICENSE_KEY_USER],
         "nbs.app_name" => @application.details['application_name'],
         "nbs.agent_log_file_name" => 'STDOUT',
         "nbs.agent_log_file_count" => agent_log_file_count,
         "nbs.agent_log_file_size" => agent_log_file_size,
         "nbs.agent_log_level" => agent_log_level
        }		
        JavaBuildpack::Util::Properties.write(@droplet.sandbox + "tingyun.properties", props_hash)
      end

      def apply_user_configuration(credentials, configuration)
        credentials.each do |key, value|
          configuration[key] = value
        end
      end

      def write_java_opts(java_opts, configuration)
        configuration.each do |key, value|
          java_opts.add_system_property("nbs.#{key}", value)
        end
      end
    end
  end
end
