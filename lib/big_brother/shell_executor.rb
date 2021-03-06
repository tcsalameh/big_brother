module BigBrother
  class ShellExecutor
    def invoke(command)
      BigBrother.logger.info("Running command: #{command.inspect}")
      _system(command)
    end

    def _system(command)
      current_fiber = Fiber.current

      EventMachine.system(command) do |output, status|
        current_fiber.resume(output, status.exitstatus)
      end

      return Fiber.yield
    end
  end
end
