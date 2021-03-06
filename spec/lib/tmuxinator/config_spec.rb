require "spec_helper"

describe Tmuxinator::Config do
  let(:fixtures_dir) { File.expand_path("../../../fixtures/", __FILE__) }
  let(:xdg_config_dir) { "#{fixtures_dir}/xdg-tmuxinator" }
  let(:home_config_dir) { "#{fixtures_dir}/dot-tmuxinator" }

  describe "#directory" do
    context "environment variable $TMUXINATOR_CONFIG non-blank" do
      it "is $TMUXINATOR_CONFIG" do
        allow(ENV).to receive(:[]).with("TMUXINATOR_CONFIG").
          and_return "expected"
        allow(File).to receive(:directory?).and_return true
        expect(Tmuxinator::Config.directory).to eq "expected"
      end
    end

    context "only ~/.tmuxinator exists" do
      it "is ~/.tmuxinator" do
        allow(File).to receive(:directory?).
          with(Tmuxinator::Config.environment).and_return false
        allow(File).to receive(:directory?).
          with(Tmuxinator::Config.xdg).and_return false
        allow(File).to receive(:directory?).
          with(Tmuxinator::Config.home).and_return true
        expect(Tmuxinator::Config.directory).to eq Tmuxinator::Config.home
      end
    end

    context "only $XDG_CONFIG_HOME/tmuxinator exists" do
      it "is #xdg" do
        allow(File).to receive(:directory?).
          with(Tmuxinator::Config.environment).and_return false
        allow(File).to receive(:directory?).
          with(Tmuxinator::Config.xdg).and_return true
        allow(File).to receive(:directory?).
          with(Tmuxinator::Config.home).and_return false
        expect(Tmuxinator::Config.directory).to eq Tmuxinator::Config.xdg
      end
    end

    context "both $XDG_CONFIG_HOME/tmuxinator and ~/.tmuxinator exist" do
      it "is #xdg" do
        allow(File).to receive(:directory?).
          with(Tmuxinator::Config.environment).and_return false
        allow(File).to receive(:directory?).
          with(Tmuxinator::Config.xdg).and_return true
        allow(File).to receive(:directory?).
          with(Tmuxinator::Config.home).and_return true
        expect(Tmuxinator::Config.directory).to eq Tmuxinator::Config.xdg
      end
    end

    context "parent directory(s) do not exist" do
      it "creates parent directories if required" do
        allow(File).to receive(:directory?).and_call_original
        allow(File).to receive(:directory?).with(Tmuxinator::Config.home).
          and_return false
        Dir.mktmpdir do |dir|
          config_parent = "#{dir}/non_existant_parent/s"
          allow(XDG).to receive(:[]).with("CONFIG").and_return config_parent
          expect(Tmuxinator::Config.directory).
            to eq "#{config_parent}/tmuxinator"
          expect(File.directory?("#{config_parent}/tmuxinator")).to be true
        end
      end
    end
  end

  describe "#enviroment" do
    context "environment variable $TMUXINATOR_CONFIG is not empty" do
      it "is $TMUXINATOR_CONFIG" do
        allow(ENV).to receive(:[]).with("TMUXINATOR_CONFIG").
          and_return "expected"
        # allow(XDG).to receive(:[]).with("CONFIG").and_return "expected"
        allow(File).to receive(:directory?).and_return true
        expect(Tmuxinator::Config.environment).to eq "expected"
      end
    end

    context "environment variable $TMUXINATOR_CONFIG is nil" do
      it "is an empty string" do
        allow(ENV).to receive(:[]).with("TMUXINATOR_CONFIG").
          and_return nil
        # allow(XDG).to receive(:[]).with("CONFIG").and_return nil
        allow(File).to receive(:directory?).and_return true
        expect(Tmuxinator::Config.environment).to eq ""
      end
    end

    context "environment variable $TMUXINATOR_CONFIG is set and empty" do
      it "is an empty string" do
        allow(XDG).to receive(:[]).with("CONFIG").and_return ""
        expect(Tmuxinator::Config.environment).to eq ""
      end
    end
  end

  describe "#directories" do
    it "is empty if no configuration directories exist" do
      allow(File).to receive(:directory?).and_return false
      expect(Tmuxinator::Config.directories).to eq []
    end

    it "is only [$TMUXINATOR_CONFIG] if set" do
      allow(ENV).to receive(:[]).with("TMUXINATOR_CONFIG").
        and_return "expected"
      allow(File).to receive(:directory?).and_return true
      expect(Tmuxinator::Config.directories).to eq ["expected"]
    end

    it "contains #xdg before #home" do
      allow(File).to receive(:directory?).with(Tmuxinator::Config.xdg).
        and_return true
      allow(File).to receive(:directory?).with(Tmuxinator::Config.home).
        and_return true
      expect(Tmuxinator::Config.directories).to eq \
        [Tmuxinator::Config.xdg, Tmuxinator::Config.home]
    end
  end

  describe "#home" do
    it "is ~/.tmuxinator" do
      expect(Tmuxinator::Config.home).to eq "#{ENV['HOME']}/.tmuxinator"
    end
  end

  describe "#xdg" do
    it "is $XDG_CONFIG_HOME/tmuxinator" do
      expect(Tmuxinator::Config.xdg).to eq "#{XDG['CONFIG_HOME']}/tmuxinator"
    end
  end

  describe "#sample" do
    it "gets the path of the sample project" do
      expect(Tmuxinator::Config.sample).to include("sample.yml")
    end
  end

  describe "#default" do
    it "gets the path of the default config" do
      expect(Tmuxinator::Config.default).to include("default.yml")
    end
  end

  describe "#version" do
    subject { Tmuxinator::Config.version }

    before do
      expect(Tmuxinator::Doctor).to receive(:installed?).and_return(true)
      allow_any_instance_of(Kernel).to receive(:`).with(/tmux\s\-V/).
        and_return("tmux #{version}")
    end

    context "master" do
      let(:version) { "master" }
      it { is_expected.to eq Float::INFINITY }
    end

    context "installed" do
      let(:version) { "2.4" }
      it { is_expected.to eq version.to_f }
    end
  end

  describe "#default_path_option" do
    context ">= 1.8" do
      before do
        allow(Tmuxinator::Config).to receive(:version).and_return(1.8)
      end

      it "returns -c" do
        expect(Tmuxinator::Config.default_path_option).to eq "-c"
      end
    end

    context "< 1.8" do
      before do
        allow(Tmuxinator::Config).to receive(:version).and_return(1.7)
      end

      it "returns default-path" do
        expect(Tmuxinator::Config.default_path_option).to eq "default-path"
      end
    end
  end

  describe "#default?" do
    let(:directory) { Tmuxinator::Config.directory }
    let(:local_default) { Tmuxinator::Config::LOCAL_DEFAULT }
    let(:proj_default) { Tmuxinator::Config.default }

    context "when the file exists" do
      before do
        allow(File).to receive(:exist?).with(local_default) { false }
        allow(File).to receive(:exist?).with(proj_default) { true }
      end

      it "returns true" do
        expect(Tmuxinator::Config.default?).to be_truthy
      end
    end

    context "when the file doesn't exist" do
      before do
        allow(File).to receive(:exist?).with(local_default) { false }
        allow(File).to receive(:exist?).with(proj_default) { false }
      end

      it "returns true" do
        expect(Tmuxinator::Config.default?).to be_falsey
      end
    end
  end

  describe "#configs" do
    before do
      allow(Tmuxinator::Config).to receive_messages(xdg: xdg_config_dir)
      allow(Tmuxinator::Config).to receive_messages(home: home_config_dir)
    end

    it "gets a sorted list of all projects" do
      expect(Tmuxinator::Config.configs).
        to eq ["both", "both", "dup/local-dup", "home", "local-dup", "xdg"]
    end

    it "lists only projects in $TMUXINATOR_CONFIG when set" do
      allow(ENV).to receive(:[]).with("TMUXINATOR_CONFIG").
        and_return "#{fixtures_dir}/TMUXINATOR_CONFIG"
      expect(Tmuxinator::Config.configs).to eq ["TMUXINATOR_CONFIG"]
    end
  end

  describe "#exists?" do
    before do
      allow(File).to receive_messages(exist?: true)
      allow(Tmuxinator::Config).to receive_messages(project: "")
    end

    it "checks if the given project exists" do
      expect(Tmuxinator::Config.exists?("test")).to be_truthy
    end
  end

  describe "#global_project" do
    let(:directory) { Tmuxinator::Config.directory }
    let(:base) { "#{directory}/sample.yml" }
    let(:first_dup) { "#{home_config_dir}/dup/local-dup.yml" }

    before do
      allow(Tmuxinator::Config).to receive_messages(xdg: fixtures_dir)
      allow(Tmuxinator::Config).to receive_messages(home: fixtures_dir)
    end

    context "with project yml" do
      it "gets the project as path to the yml file" do
        expect(Tmuxinator::Config.global_project("sample")).to eq base
      end
    end

    context "without project yml" do
      it "gets the project as path to the yml file" do
        expect(Tmuxinator::Config.global_project("new-project")).to be_nil
      end
    end

    context "with duplicate project files" do
      it "is the first .yml file found" do
        expect(Tmuxinator::Config.global_project("local-dup")).to eq first_dup
      end
    end
  end

  describe "#local?" do
    it "checks if the given project exists" do
      path = Tmuxinator::Config::LOCAL_DEFAULT
      expect(File).to receive(:exist?).with(path) { true }
      expect(Tmuxinator::Config.local?).to be_truthy
    end
  end

  describe "#local_project" do
    let(:default) { Tmuxinator::Config::LOCAL_DEFAULT }

    context "with a project yml" do
      it "gets the project as path to the yml file" do
        expect(File).to receive(:exist?).with(default) { true }
        expect(Tmuxinator::Config.local_project).to eq default
      end
    end

    context "without project yml" do
      it "gets the project as path to the yml file" do
        expect(Tmuxinator::Config.local_project).to be_nil
      end
    end
  end

  describe "#project" do
    let(:directory) { Tmuxinator::Config.directory }
    let(:default) { Tmuxinator::Config::LOCAL_DEFAULT }

    context "with an non-local project yml" do
      before do
        allow(Tmuxinator::Config).to receive_messages(directory: fixtures_dir)
      end

      it "gets the project as path to the yml file" do
        expect(Tmuxinator::Config.project("sample")).
          to eq "#{directory}/sample.yml"
      end
    end

    context "with a local project, but no global project" do
      it "gets the project as path to the yml file" do
        expect(File).to receive(:exist?).with(default) { true }
        expect(Tmuxinator::Config.project("sample")).to eq "./.tmuxinator.yml"
      end
    end

    context "without project yml" do
      let(:expected) { "#{directory}/new-project.yml" }
      it "gets the project as path to the yml file" do
        expect(Tmuxinator::Config.project("new-project")).to eq expected
      end
    end
  end

  describe "#validate" do
    let(:default) { Tmuxinator::Config::LOCAL_DEFAULT }

    context "when a project name is provided" do
      it "should raise if the project file can't be found" do
        expect do
          Tmuxinator::Config.validate(name: "sample")
        end.to raise_error RuntimeError, %r{Project.+doesn't.exist}
      end

      it "should load and validate the project" do
        expect(Tmuxinator::Config).to receive_messages(directory: fixtures_dir)
        expect(Tmuxinator::Config.validate(name: "sample")).to \
          be_a Tmuxinator::Project
      end
    end

    context "when no project name is provided" do
      it "should raise if the local project file doesn't exist" do
        expect(File).to receive(:exist?).with(default) { false }
        expect do
          Tmuxinator::Config.validate
        end.to raise_error RuntimeError, %r{Project.+doesn't.exist}
      end

      it "should load and validate the project" do
        content = File.read(File.join(fixtures_dir, "sample.yml"))

        expect(File).to receive(:exist?).with(default).at_least(:once) { true }
        expect(File).to receive(:read).with(default).and_return(content)

        expect(Tmuxinator::Config.validate).to be_a Tmuxinator::Project
      end
    end
  end
end
