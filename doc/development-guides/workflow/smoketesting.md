This file documents the OpenCrowbar smoketest framework

**Note:** The default admin node memory allocation is 4G.  It may be necessary to
run smoke tests with more (6 or 8G) to get speedy or reliable results.

##The smoketest framework lives on the admin node, and consists of:

  * smoketest
    This is the front-end to the in-cluster side of the smoketest framework.
    It takes a single parameter, which is the name of a barclamp to smoketest.
    smoketest must be run as root.
  * check_ready
    This checks to see if a node had transitioned to a given state.
    smoketest uses it internally.
  * run_on
    This runs a command on a given node as root.
  * knife_node_find
    This is a very thin and stupid wrapper around knife search node.
  * name_to_ip
    This translates an hostname into an IP address.
  * parse_yml_or_json
    This is a cheesy little function that parses yml (or JSON), extracts
    fields of interest, and prints them in a form suitable for bash's eval.

##The smoketest command works like this:

  * Your admin node is in the ready state, and the rest of the nodes are
    in discovered.
  * You run /opt/dell/bin/smoketest nova (for example).
  * smoketest allocates all the nodes, and waits for them to transition
    to ready. If any node transitions to problem, the smoketest fails.
  * Once all the nodes are in ready state, smoketest will examine the barclamp
    metadata for all installed barclamps. It will then deploy and test all the
    barclamps needed to meet the dependencies of the barclamp to test, including
    itself.
  * The output from all the tests along with the proposals that were created,
    modified, and deployed will be saved in /var/log/smoketests.
  * If any deploys or tests fail, the smoketest fails.
  * You can test more than one barclamp at a time by passing multiple arguments
    to the smoketest command:
    /opt/dell/bin/smoketest nova_dashboard swift tempest
    will run the smoketests for nova_dashboard, swift and tempest and all
    the barclamps they depend on.
  * It is a good idea to make sure that the admin node has IP addresses on
    the public, storage, and nova_fixed networks.  The dev tool and
    test_crowbar.sh do this automatically, otherwise you can run this script
    on the admin node to add the networks:

##Writing Barclamp Smoketests

  Barclamp smoketests consists of three parts:
  * Smoketest Metadata.
    This consists of metadata in the barclamp's crowbar.yml that declares any 
    smoketest-specific barclamp dependencies and an overall timeout that the
    smoketest for this barclamp cannot exceed.  The smoketests use the
    following metadata:
    * barclamp.requires and smoketest.requires
      Any barclamps that are in these arrays will be deployed and smoketested
      before the current smoketest.
    * barclamp.member
      This is used to satisfy group dependencies if a group is listed as 
      a dependency in the barclamp.requires and smoketest.requires.
    * smoketest.timeout
      This is the number of seconds that a smoketest can run before the 
      framework decides that it is never going to finish and returns failure. 
  * smoketest/modify-json
    This executable should accept the proposal JSON on stdin, make whatever
    changes are needed to let it run in the framework (changing free space
    requirements, replication factors, etc), and write the modified JSON to
    stdout.
  * smoketest/*.test
    These executables should each perform a discrete test of the barclamp. The
    smoketest framework will run them in ascending order, and the first test
    that exits with a nonzero status will signal that the overall smoketest
    for this barclamp failed, and the framework will stop processing further
    tests. The framework does not care what language the tests are written in,
    as long as the build/test system can run them.
    The smoketest framework arranges for the crowbar CLI and the framework 
    helper commands to be available during the run.  Any output from the test
    hooks will be captured and logged.
  
Any other files will be ignored by the smoketest framework -- you can use them
for shared libraries, templates, etc. as the needs of your smoketest require.

