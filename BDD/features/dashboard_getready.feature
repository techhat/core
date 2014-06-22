Feature: Dashboard GetReady
  In order setup my system
  The system operator, Oscar
  wants to be able to quickly allocate deployment, network and node O/S

  Scenario: UI Node List
    Given REST creates the {object:node} "ready.set.go"
      And there are no pending Crowbar runs for {o:node} "ready.set.go"
    When I go to the "dashboard/getready" page
    Then I should see {bdd:crowbar.i18n.dashboard.getready.title}
      And I should see "ready.set.go"
      And I should see {lookup:crowbar.node_name}
      And there should be no translation errors
    Finally REST removes the {object:node} "ready.set.go"

  Scenario: UI Node List Click to Node
    Given I am on the "dashboard/getready" page
    When I click on the "admin.bddtesting.com" link
    Then I should see {lookup:crowbar.node_name}
      And there should be no translation errors
