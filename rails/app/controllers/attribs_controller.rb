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
#
#
class AttribsController < ApplicationController

  def index
    target = find_target
    @list = target.nil? ? Attrib.all : target.attribs
    respond_to do |format|
      format.html { }
      format.json { render api_index :attrib, @list }
    end
  end

  def show
    target = find_target
    @attrib = Attrib.find_key params[:id]
    if target.nil?
      respond_to do |format|
        format.html {  }
        format.json { render api_show @attrib }
      end
    else
      ret = @attrib.as_json
      ret["value"] = @attrib.get(target)
      render json: ret, content_type: cb_content_type(@attrib, "obj")
    end
  end

  def create
    if params.has_key? :node_id
      render api_not_supported 'post', 'nodes/:node_id/attribs/:id'
    else
      render api_not_supported 'post', 'attribs'
    end
  end

  def update
    target = find_target
    if target.nil?
      # We do not allow updating attribs outside the context of
      # some other object.
      render api_not_supported 'put', 'attribs/:id'
      return
    end
    params.require(:value)
    attrib = Attrib.find_key(params[:id])
    target.attribs.find(attrib.id).set(target,params[:value], :user)
    ret = attrib.as_json
    ret["value"] = params[:value]
    render json: ret, content_type: cb_content_type(attrib, "obj")
  end

  def destroy
    render api_not_supported 'delete', 'attribs/:id'
  end

  private

  def find_target
    case
    when params.has_key?(:node_id) then Node.find_key(params[:node_id])
    when params.has_key?(:role_id) then Role.find_key(params[:role_id])
    when params.has_key?(:node_role_id) then NodeRole.find_key(params[:node_role_id])
    when params.has_key?(:snapshot_id) then Snapshot.find_key(params[:snapshot_id])
    when params.has_key?(:deployment_id) then Deployment.find_key(params[:deployment_id]).snapshot
    when params.has_key?(:deployment_role_id) then DeploymentRole.find_key(params[:deployment_role_id])
    else nil
    end
  end

end
