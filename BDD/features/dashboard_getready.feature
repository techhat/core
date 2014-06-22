Feature: Dashboard GetReady
  In order setup my system
  The system operator, Oscar
  wants to be able to quickly allocate deployment, network and node O/S

  Scenario: UI Node List
    Given REST creates the {object:node} "ready.set.go"
      And there are no pending Crowbar runs for {o:node} "ready.set.go"
    When I go to the "dashboard/getready" page
    Then I should see {bdd:crowbar.i18n.nodes.getready.title}
      And I should see "ready.set.go"
      And there should be no translation errors
    Finally REST removes the {object:node} "ready.set.go"

  Scenario: UI Node List Click to Node
    Given REST creates the {object:node} "ready1.set.go"
      And there are no pending Crowbar runs for {o:node} "ready1.set.go"
      And I am on the "dashboard/getready" page
    When I click on the "ready1.set.go" link
    Then I should see a heading "1ready.set.go" 
      And there should be no translation errors
    Finally REST removes the {object:node} "ready1.set.go"
