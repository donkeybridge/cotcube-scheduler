module Cotcube
  module Scheduler
    module CommandParser include Raabro
      def space(input);        rex(nil,            input, /\s+/);                                             end

      # a cmdstring consists of string containing no whitespace, starting with a character, / or .
      def cmd_string(input);   rex(:command,       input, /[\/.\w][^&'" =]*/);                                end

      # an envstring is a string being < var >< = >< value >
      # where var is a letter followed by zero or more characters or '_'
      # where val is either a string without whitespace and quotes or a quote (NOTE: Quoting does not work appropriately, use '" "')
      def env_string(input);   rex(:env_string,    input, /[A-Za-z]+[\w_]*=(?:[^\s&'"]+|'[^']*'|"[^"]*")+/);  end
      def env_series(input);   jseq(nil,           input, :env_string, :space);                               end

      # the valuestring is defined above as 'val'
      def value_string(input); rex(:arg_string,    input, /(?:[^ &'"]+|'[^']*'|"[^"]*")+/);                   end
      def args(input);        jseq(nil,            input, :value_string, :space);                             end

      def precompound(input);  seq(nil,            input, :env_series, :space, :cmd_string)                   end
      def precmd(input);       alt(nil,            input, :precompound, :cmd_string)                          end

      def fullcompound(input); seq(nil,            input, :precmd, :space, :args)                             end
      def fullcmd(input);      alt(:fullcmd,       input, :fullcompound, :cmd_string)                         end

      def rewrite_fullcmd(tree)
        { 
          env:     tree.subgather(:env_string).map{|z| z.string },
          command: tree.subgather(:command   ).map{|z| z.string }.first,
          args:    tree.subgather(:arg_string).map{|z| z.string }
        }
      end
    end

  end
end
