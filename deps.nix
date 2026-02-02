{ lib, beamPackages, overrides ? (x: y: {}) }:

let
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildErlangMk = lib.makeOverridable beamPackages.buildErlangMk;

  self = packages // (overrides self packages);

  packages = with beamPackages; with self; {
    bandit = buildMix rec {
      name = "bandit";
      version = "1.10.2";

      src = fetchHex {
        pkg = "bandit";
        version = "${version}";
        sha256 = "27b2a61b647914b1726c2ced3601473be5f7aa6bb468564a688646a689b3ee45";
      };

      beamDeps = [ hpax plug telemetry thousand_island websock ];
    };

    cc_precompiler = buildMix rec {
      name = "cc_precompiler";
      version = "0.1.11";

      src = fetchHex {
        pkg = "cc_precompiler";
        version = "${version}";
        sha256 = "3427232caf0835f94680e5bcf082408a70b48ad68a5f5c0b02a3bea9f3a075b9";
      };

      beamDeps = [ elixir_make ];
    };

    db_connection = buildMix rec {
      name = "db_connection";
      version = "2.9.0";

      src = fetchHex {
        pkg = "db_connection";
        version = "${version}";
        sha256 = "17d502eacaf61829db98facf6f20808ed33da6ccf495354a41e64fe42f9c509c";
      };

      beamDeps = [ telemetry ];
    };

    decimal = buildMix rec {
      name = "decimal";
      version = "2.3.0";

      src = fetchHex {
        pkg = "decimal";
        version = "${version}";
        sha256 = "a4d66355cb29cb47c3cf30e71329e58361cfcb37c34235ef3bf1d7bf3773aeac";
      };

      beamDeps = [];
    };

    ecto = buildMix rec {
      name = "ecto";
      version = "3.13.5";

      src = fetchHex {
        pkg = "ecto";
        version = "${version}";
        sha256 = "df9efebf70cf94142739ba357499661ef5dbb559ef902b68ea1f3c1fabce36de";
      };

      beamDeps = [ decimal jason telemetry ];
    };

    ecto_sql = buildMix rec {
      name = "ecto_sql";
      version = "3.13.4";

      src = fetchHex {
        pkg = "ecto_sql";
        version = "${version}";
        sha256 = "2b38cf0749ca4d1c5a8bcbff79bbe15446861ca12a61f9fba604486cb6b62a14";
      };

      beamDeps = [ db_connection ecto telemetry ];
    };

    ecto_sqlite3 = buildMix rec {
      name = "ecto_sqlite3";
      version = "0.22.0";

      src = fetchHex {
        pkg = "ecto_sqlite3";
        version = "${version}";
        sha256 = "5af9e031bffcc5da0b7bca90c271a7b1e7c04a93fecf7f6cd35bc1b1921a64bd";
      };

      beamDeps = [ decimal ecto ecto_sql exqlite ];
    };

    elixir_make = buildMix rec {
      name = "elixir_make";
      version = "0.9.0";

      src = fetchHex {
        pkg = "elixir_make";
        version = "${version}";
        sha256 = "db23d4fd8b757462ad02f8aa73431a426fe6671c80b200d9710caf3d1dd0ffdb";
      };

      beamDeps = [];
    };

    exqlite = buildMix rec {
      name = "exqlite";
      version = "0.34.0";

      src = fetchHex {
        pkg = "exqlite";
        version = "${version}";
        sha256 = "bcdc58879a0db5e08cd5f6fbe07a0692ceffaaaa617eab46b506137edf0a2742";
      };

      beamDeps = [ cc_precompiler db_connection elixir_make ];
    };

    hpax = buildMix rec {
      name = "hpax";
      version = "1.0.3";

      src = fetchHex {
        pkg = "hpax";
        version = "${version}";
        sha256 = "8eab6e1cfa8d5918c2ce4ba43588e894af35dbd8e91e6e55c817bca5847df34a";
      };

      beamDeps = [];
    };

    jason = buildMix rec {
      name = "jason";
      version = "1.4.4";

      src = fetchHex {
        pkg = "jason";
        version = "${version}";
        sha256 = "c5eb0cab91f094599f94d55bc63409236a8ec69a21a67814529e8d5f6cc90b3b";
      };

      beamDeps = [ decimal ];
    };

    mime = buildMix rec {
      name = "mime";
      version = "2.0.7";

      src = fetchHex {
        pkg = "mime";
        version = "${version}";
        sha256 = "6171188e399ee16023ffc5b76ce445eb6d9672e2e241d2df6050f3c771e80ccd";
      };

      beamDeps = [];
    };

    plug = buildMix rec {
      name = "plug";
      version = "1.19.1";

      src = fetchHex {
        pkg = "plug";
        version = "${version}";
        sha256 = "560a0017a8f6d5d30146916862aaf9300b7280063651dd7e532b8be168511e62";
      };

      beamDeps = [ mime plug_crypto telemetry ];
    };

    plug_crypto = buildMix rec {
      name = "plug_crypto";
      version = "2.1.1";

      src = fetchHex {
        pkg = "plug_crypto";
        version = "${version}";
        sha256 = "6470bce6ffe41c8bd497612ffde1a7e4af67f36a15eea5f921af71cf3e11247c";
      };

      beamDeps = [];
    };

    telemetry = buildRebar3 rec {
      name = "telemetry";
      version = "1.3.0";

      src = fetchHex {
        pkg = "telemetry";
        version = "${version}";
        sha256 = "7015fc8919dbe63764f4b4b87a95b7c0996bd539e0d499be6ec9d7f3875b79e6";
      };

      beamDeps = [];
    };

    thousand_island = buildMix rec {
      name = "thousand_island";
      version = "1.4.3";

      src = fetchHex {
        pkg = "thousand_island";
        version = "${version}";
        sha256 = "6e4ce09b0fd761a58594d02814d40f77daff460c48a7354a15ab353bb998ea0b";
      };

      beamDeps = [ telemetry ];
    };

    websock = buildMix rec {
      name = "websock";
      version = "0.5.3";

      src = fetchHex {
        pkg = "websock";
        version = "${version}";
        sha256 = "6105453d7fac22c712ad66fab1d45abdf049868f253cf719b625151460b8b453";
      };

      beamDeps = [];
    };
  };
in self

