module Msf
  class Plugin::Fuzzy_Use < Msf::Plugin
    def name
      "fuzzy_use"
    end

    def desc
      "Use fzf to provide a nicer module selection experience."
    end

    def initialize(framework, opts)
      super

      modules_table = Rex::Text::Table.new(
        "WordWrap" => false,
        "Columns" => [
          "Name",
          "Disclosure Date",
          "Rank",
          "Check",
          "Name",
          "Description",
        ],
        "ColProps" => {
          "Rank" => {
            "Formatters" => [Msf::Ui::Console::TablePrint::RankFormatter.new],
          },
        },
      )
      modules = Msf::Modules::Metadata::Cache.instance.find({})
      modules.each do |mod|
        modules_table << [
          mod.fullname,
          mod.disclosure_date.nil? ? "" : mod.disclosure_date.strftime("%Y-%m-%d"),
          mod.rank,
          mod.check ? "Yes" : "No",
          mod.name,
          "#" + mod.description.gsub(/\s+/, " "),
        ]
      end

      $modules_table = modules_table.to_s

      add_console_dispatcher(Fuzzy_Use_Dispatcher)
    end

    class Fuzzy_Use_Dispatcher < Msf::Ui::Console::CommandDispatcher::Modules
      include Msf::Ui::Console::CommandDispatcher

      def name
        "Fuzzy_Use_Dispatcher"
      end

      def commands
        {
          "use" => "Interact with a module by name or search term/index",
        }
      end

      alias_method :old_cmd_use, :cmd_use unless method_defined? :old_cmd_use

      def cmd_use(*args)
        if args.length == 0
          fzf_arguments = [
            "--history=/dev/shm/msf_fuzzy_use_history",
            "--exact",
            "--no-hscroll",
            "--preview",
            'echo {} |cut -d "#" -f 2',
            "--preview-window",
            "down:3:wrap",
            "--no-info",
            "--cycle",
            "--tac",
            "--border",
            "--multi",
            "--header-lines=2",
            "--bind=tab:toggle+down,btab:deselect-all,enter:toggle+accept",
            "--prompt",
            "Select a module to use > ",
          ]
          chosen_one = IO.popen(["fzf"] + fzf_arguments, "r+") { |fzf|
            fzf.write($modules_table)
            fzf.read.split(" ").first
          }
          args = chosen_one == nil ? [] : [chosen_one]
        end

        old_cmd_use(*args)
      end
    end

    def cleanup
      $modules_table = nil
      remove_console_dispatcher("Fuzzy_Use_Dispatcher")
    end

    protected
  end
end
