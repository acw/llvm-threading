%Ticks     = type i64 ; share this with external parties
%TimeT     = type i64
%TimeSpec  = type { %TimeT, %TimeT }

declare i64  @clock_gettime(i32, %TimeSpec*)
declare i32  @clock_nanosleep(i32, i32, %TimeSpec*, %TimeSpec*)
declare i32  @printf(i8* noalias nocapture, ...)
declare void @exit(i32) noreturn

;
; A tick is 64 microseconds. log_2 64 = 6
;

define %Ticks @microsecondsToTicks(i64 %microseconds)
{
    %res = ashr i64 %microseconds, 6
    ret %Ticks %res
}

define i64 @ticksToMicroseconds(%Ticks %ticks)
{
    %res = shl i64 %ticks, 6
    ret i64 %res
}

define %Ticks @secondsToTicks(i64 %seconds)
{
    %msecs = mul i64 %seconds, 1000000
    %res   = call i64 @microsecondsToTicks(i64 %msecs)
    ret i64 %res
}

define %Ticks @timespecToTicks(%TimeSpec* %tval)
{
    %secp  = getelementptr %TimeSpec* %tval, i32 0, i32 0
    %nsecp = getelementptr %TimeSpec* %tval, i32 0, i32 1
    %secs  = load i64* %secp
    %nsecs = load i64* %nsecp
    %usecs = sdiv i64 %nsecs, 1000
    %val1  = call %Ticks @secondsToTicks(i64 %secs)
    %val2  = call %Ticks @microsecondsToTicks(i64 %usecs)
    %res   = add %Ticks %val1, %val2
    ret i64 %res
}

define void @ticksToTimespec(%Ticks %ticks, %TimeSpec* %tval)
{
    %secp  = getelementptr %TimeSpec* %tval, i32 0, i32 0
    %nsecp = getelementptr %TimeSpec* %tval, i32 0, i32 1
    %usecs = call i64 @ticksToMicroseconds(%Ticks %ticks)
    %nsecs = mul i64 %usecs, 1000
    %sec   = sdiv i64 %nsecs, 1000000000
    %nsec  = srem i64 %nsecs, 1000000000
    store i64 %sec, i64* %secp
    store i64 %nsec, i64* %nsecp
    ret void
}

define %Ticks @getTicks()
{
    %temp  = alloca %TimeSpec
    br label %tryAgain

tryAgain: 
    %gtres = call i64 @clock_gettime(i32 1, %TimeSpec* %temp) ; 1=CLOCK_MONOTONIC
    %isOK  = icmp eq i64 %gtres, 0
    br i1 %isOK, label %returnTime, label %tryAgain

returnTime:
    %res   = call i64 @timespecToTicks(%TimeSpec* %temp)
    ret i64 %res
}

@.ERR_weird   = internal constant [47 x i8] 
         c"Called clock_nanosleep and got weird response.\00"
@.ERR_badaddr = internal constant [43 x i8]
         c"Called clock_nanosleep with bad addresses.\00"
@.ERR_badtval = internal constant [45 x i8]
         c"Called clock_nanosleep with bad tval values.\00"
@.ERR         = internal constant [11 x i8]
         c"ERROR: %s\0a\00"

define void @sleepFor(%Ticks %ticks)
{
    %skipSleep = icmp slt %Ticks %ticks, 128
    br i1 %skipSleep, label %done, label %startSleep

startSleep:
    %tval      = alloca %TimeSpec
    call void @ticksToTimespec(%Ticks %ticks, %TimeSpec* %tval)
    br label %doSleep

doSleep:
    %sleepFor  = phi %TimeSpec* [%tval, %startSleep], [%rem, %doSleep]
    %rem       = alloca %TimeSpec
    %res       = call i32 @clock_nanosleep(i32 1, ; CLOCK_MONOTONIC
                                           i32 0, ; TIMER_RELTIME
                                           %TimeSpec* %sleepFor, ; request
                                           %TimeSpec* %rem) ;remain
    switch i32 %res, label %weird [
        i32 0,  label %done               ; no error
        i32 14, label %invalidAddress     ; EFAULT
        i32 22, label %invalidTime        ; EINVAL
        i32 4,  label %doSleep            ; EINTR
      ]

weird:
    %errstrW   = getelementptr [47 x i8]* @.ERR_weird, i32 0, i32 0
    br label %error

invalidAddress:
    %errstrIA  = getelementptr [43 x i8]* @.ERR_badaddr, i32 0, i32 0
    br label %error

invalidTime:
    %errstrIT  = getelementptr [45 x i8]* @.ERR_badtval, i32 0, i32 0
    br label %error

error:
    %errstr    = phi i8* [%errstrW, %weird], [%errstrIA, %invalidAddress],
                         [%errstrIT, %invalidTime]
    %basestr   = getelementptr [11 x i8]* @.ERR, i32 0, i32 0
    call i32(i8*,...)* @printf(i8* %basestr, i8* %errstr)
    call void @exit(i32 -1)
    unreachable

done:
    ret void
}
