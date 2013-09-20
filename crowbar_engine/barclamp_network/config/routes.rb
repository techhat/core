# Copyright 2013, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

BarclampNetwork::Engine.routes.draw do

  # UI routes
  resources :networks

  #/api/v2/networks
  scope :defaults => {:format=> 'json'} do
    constraints( :id => /([a-zA-Z0-9\-\.\_]*)/, :version => /v[1-9]/ ) do
      scope 'api' do
        scope ':version' do
          resources :routers
          resources :ranges
          resources :allocations
          resources :networks do
            member do
              match 'ip'
              post 'allocate_ip'
            end
          end
        end
      end
    end
  end
end
