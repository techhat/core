Feature: Dashboard GetReady
  In order setup my system
  The system operator, Oscar
  wants to be able to quickly allocate deployment, network and node O/S

  Scenario: UI Node List
    Given REST creates the {object:node} "ready.set.go"
      And there are no pending Crowbar runs for {o:node} "ready.set.go"
    When I go to the "dashboard/getready" page
    Then I should see {bdd:crowbar.i18n.dashboard.getready.title}
      And I should see an input box "deployment" with {bdd:crowbar.i18n.dashboard.getready.default}
      And I should see an input box "range" with {bdd:crowbar.i18n.dashboard.getready.range_base}
      And I should see an input box "conduit" with "1g1"
      And I should see an input box "first_ip" with "10.10.10.10/24"
      And I should see an input box "last_ip" with "10.10.10.250/24"
      And I should see "ready.set.go"
      And I should see {lookup:crowbar.node_name}
      And there should be no translation errors
    Finally REST removes the {object:node} "ready.set.go"

  Scenario: UI Node List Click to Node
    Given I am on the "dashboard/getready" page
    When I click on the "admin.bddtesting.com" link
    Then I should see {lookup:crowbar.node_name}
      And there should be no translation errors

  Scenario: GetReady Create Deployment
    Given there is not a {object:deployment} "getready"
      And I post {fields:deployment=getready&conduit=} to "dashboard/getready"
    When REST gets the {object:deployment} "getready" 
    Then I get a {integer:200} result
      And key "name" should be "getready"
      And the {object:deployment} is properly formatted
    Finally REST removes the {object:deployment} "getready"