# Copyright 2012, Dell
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

require 'spec_helper'

describe CrowbarUtils do
  describe "Locking functions" do
    it "should raise an exception if file create fails" do
      allow(File).to receive_messages(:new => nil)
      expect {
        CrowbarUtils.lock_held?("fred")
      }.to raise_error(IOError, "File not available: tmp/fred.lock")
    end

    it "lock_held? should return true iff the lock is held" do
      f1 = double('fred')
      expect(f1).to receive(:flock).and_return(false)
      allow(File).to receive_messages(:new => f1)
      allow(f1).to receive(:close)
      expect(CrowbarUtils.lock_held?("fred")).to be true
    end

    it "lock_held? should return false iff the lock is not held" do
      f1 = double('fred')
      expect(f1).to receive(:flock).exactly(2).and_return(true, true)
      allow(File).to receive_messages(:new => f1)
      allow(f1).to receive(:close)
      expect(CrowbarUtils.lock_held?("fred")).to be false
    end

    it "with_lock should yield when lock grabbed" do
      f1 = double('fred')
      expect(f1).to receive(:flock).exactly(2).and_return(true,true)
      allow(File).to receive_messages(:new => f1)
      allow(f1).to receive(:close)
      answer = CrowbarUtils.with_lock("fred") do
        "fred"
      end
      expect(answer).to eq("fred")
    end

    it "with_lock should die if it cannot grab lock" do
      f1 = double('fred')
      expect(f1).to receive(:flock).exactly(32).and_return(false)
      allow(File).to receive_messages(:new => f1)
      allow(Kernel).to receive(:sleep)
      allow(f1).to receive(:close)
      expect {
        CrowbarUtils.with_lock("fred") do
          "fred"
        end
      }.to raise_error(RuntimeError, "Unable to grab fred lock -- Probable deadlock.")
    end
  end
end

