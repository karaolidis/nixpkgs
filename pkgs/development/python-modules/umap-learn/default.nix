{
  lib,
  bokeh,
  buildPythonPackage,
  colorcet,
  datashader,
  fetchFromGitHub,
  setuptools,
  holoviews,
  matplotlib,
  numba,
  numpy,
  pandas,
  pynndescent,
  pytestCheckHook,
  scikit-image,
  scikit-learn,
  scipy,
  seaborn,
  tensorflow,
  tensorflow-probability,
  tqdm,
}:

buildPythonPackage rec {
  pname = "umap-learn";
  version = "0.5.7";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "lmcinnes";
    repo = "umap";
    tag = "release-${version}";
    hash = "sha256-hPYmRDSeDa4JWGekUVq3CWf5NthHTpMpyuUQ1yIkVAE=";
  };

  build-system = [ setuptools ];

  dependencies = [
    numba
    numpy
    pynndescent
    scikit-learn
    scipy
    tqdm
  ];

  optional-dependencies = rec {
    plot = [
      bokeh
      colorcet
      datashader
      holoviews
      matplotlib
      pandas
      scikit-image
      seaborn
    ];

    parametric_umap = [
      tensorflow
      tensorflow-probability
    ];

    tbb = [ tbb ];

    all = plot ++ parametric_umap ++ tbb;
  };

  nativeCheckInputs = [ pytestCheckHook ];

  preCheck = ''
    export HOME=$TMPDIR
  '';

  disabledTests = [
    # Plot functionality requires additional packages.
    # These test also fail with 'RuntimeError: cannot cache function' error.
    "test_plot_runs_at_all"
    "test_umap_plot_testability"
    "test_umap_update_large"

    # Flaky test. Fails with AssertionError sometimes.
    "test_sparse_hellinger"
    "test_densmap_trustworthiness_on_iris_supervised"

    # tensorflow maybe incompatible? https://github.com/lmcinnes/umap/issues/821
    "test_save_load"
  ];

  meta = with lib; {
    description = "Uniform Manifold Approximation and Projection";
    homepage = "https://github.com/lmcinnes/umap";
    changelog = "https://github.com/lmcinnes/umap/releases/tag/release-${version}";
    license = licenses.bsd3;
    maintainers = [ ];
  };
}
